package Alfred::MemoryService;

=head1 NAME

Alfred::MemoryService - Service for managing and recalling memories for an AI assistant.

=head1 SYNOPSIS

    use Alfred::MemoryService;

    my $memory_service = Alfred::MemoryService->new(
        ollama             => $ollama_client, # Optional, defaults to new Alfred::OllamaClient
        qdrant             => $qdrant_client, # Optional, defaults to new Qdrant::Client
        max_memories       => 500,           # Optional, defaults to 1000
        pruning_batch_size => 20             # Optional, defaults to 50
    );

    $memory_service->store_prompt("User said hello", "AI responded hi");
    my $context = $memory_service->get_context_for_prompt("User asks about weather");

=head1 DESCRIPTION

Alfred::MemoryService provides a way to store interactions (prompts and responses)
and retrieve relevant context for new prompts. It uses Ollama for generating
embeddings and extracting concepts, and Qdrant for storing and searching memories
(vectorized prompts).

It also implements a memory management strategy to limit the total number of
stored memories.

=head1 CONFIGURATION

The constructor C<new()> accepts the following parameters:

=over 4

=item C<ollama>

An optional instance of C<Alfred::OllamaClient>. If not provided, a new one
will be instantiated.

=item C<qdrant>

An optional instance of C<Qdrant::Client>. If not provided, a new one
will be instantiated.

=item C<max_memories>

The maximum number of memories (prompt-response pairs) to store. When the
number of stored memories exceeds this limit, the service will prune the
oldest entries.
Default: 1000.

=item C<pruning_batch_size>

Determines how many memories are typically deleted when C<max_memories> is
exceeded. If the number of memories over the limit is greater than this
batch size, more memories will be deleted to ensure the count drops
below or at C<max_memories>.
Default: 50.

=back

=head1 MEMORY MANAGEMENT

When a new memory is stored, the service checks if the total number of memories
exceeds C<max_memories>. If it does, the service prunes (deletes) the oldest
memories. The number of memories deleted is the larger of C<pruning_batch_size>
or the actual number of memories exceeding the C<max_memories> limit. This
ensures that the memory store is brought back to the C<max_memories> limit
(or just below it) after pruning.

=cut

use v5.40;
use strict;
use warnings;

use feature 'class';
use feature 'try';
use feature 'signatures';

use FindBin qw/$Bin/;
use lib "$Bin/../lib";

use Alfred::OllamaClient;
use Qdrant::Client;

use Carp qw/croak carp/;
use List::Util qw(max); # Added for pruning logic

no warnings 'experimental::class';
no warnings 'experimental::try';
no warnings 'experimental::signatures';

class Alfred::MemoryService 
{
    field $ollama :param;
    field $qdrant :param;

    field $collection_name = 'memories';
    field $vector_size = 384;  
    field $concept_threshold = 0.7;
    field $max_memories :param = 1000; # Default max memories
    field $pruning_batch_size :param = 50; # Default pruning batch size

    field $DISTANCE = 'Cosine';

    ADJUST 
    {
        $ollama //= Alfred::OllamaClient->new;
        $qdrant //= Qdrant::Client->new;
        # $max_memories will be set if provided in new(), otherwise defaults to 1000
        
        try 
        {
            $self->_init_collection();
        }

        catch ($e) 
        {
            croak sprintf("Failed to initialize memory storage: %s", $e);
        }
    }

    method _init_collection 
    {
        try 
        {
            $qdrant->create_collection(
                collection_name => $collection_name,
                vector_size => $vector_size,
                distance => $DISTANCE,
            );
        }

        catch ($e) 
        {
            croak $e if !$e =~ /already exists/;
        }
    }

    method store_prompt($prompt, $response) 
    {
        my $collection_info = $self->qdrant->get_collection_info(collection_name => $self->collection_name);

        if ($collection_info && exists $collection_info->{result}{points_count}) {
            my $current_points_count = $collection_info->{result}{points_count};
            if ($current_points_count > $self->{max_memories}) {
                my $num_actually_over_limit = $current_points_count - $self->{max_memories};
                # Determine how many points to delete. At least the batch size, but more if we're way over.
                my $num_to_delete = max($self->{pruning_batch_size}, $num_actually_over_limit);
                # Ensure we don't try to delete more points than exist (shouldn't happen with this logic but good practice)
                $num_to_delete = $current_points_count if $num_to_delete > $current_points_count;

                carp "Memory limit ($self->{max_memories}) exceeded by $num_actually_over_limit. Current points: $current_points_count. Attempting to prune $num_to_delete oldest memories.";

                if ($num_to_delete > 0) {
                    # Fetch all current_points_count points to ensure we correctly identify the oldest ones.
                    # This remains potentially memory intensive for very large collections.
                    my $points_to_fetch = $current_points_count;

                    my @fetched_points = $self->qdrant->list_points(
                        collection_name => $self->collection_name,
                        limit           => $points_to_fetch,
                        with_payload    => \1 # Need payload for timestamp
                    );

                    if (@fetched_points) {
                        my @sorted_points = sort {
                            ($a->{payload}{timestamp} || 0) <=> ($b->{payload}{timestamp} || 0)
                        } @fetched_points;

                        my @points_to_delete = splice(@sorted_points, 0, $num_to_delete);
                        my @ids_to_delete = map { $_->{id} } @points_to_delete;

                        if (@ids_to_delete) {
                            $self->qdrant->delete_points(
                                collection_name => $self->collection_name,
                                point_ids       => \@ids_to_delete
                            );
                            carp "Pruned " . scalar(@ids_to_delete) . " oldest memories. New estimated count: " . ($current_points_count - scalar(@ids_to_delete));
                        } else {
                            carp "Pruning attempted (target: $num_to_delete), but no IDs were selected for deletion.";
                        }
                    } else {
                        carp "Pruning needed (target: $num_to_delete), but failed to fetch points to determine oldest ones.";
                    }
                }
            }
        } else {
            carp "Could not retrieve collection info or points_count for $self->{collection_name}. Skipping memory limit check.";
        }

        my $embedding = $self->get_embedding($prompt);
        my $concepts = $self->extract_concepts($prompt);
        
        my $point = {
            id => time() . rand(1000), 
            vector => $embedding,
            payload => {
                prompt => $prompt,
                response => $response,
                concepts => $concepts,
                timestamp => time(),
            }
        };

        $qdrant->upsert_points(
            collection_name => $collection_name,
            points => [
                $point,
            ],
        );

        return $point;
    }

    method get_embedding($text) 
    {

        try 
        {   
            my $response = $ollama->generate(
                prompt => "Generate an embedding for this text: $text",
                model => 'nomic-embed-large',
                options => {
                    embedding => 1 
                }
            );

            return $response->{embedding};
        }

        catch ($e) 
        {
            croak sprintf("Failed to generate embedding: %s", $e);
        }
    }

    method find_relevant_memories($query, $limit = 5) 
    {
        my $query_embedding = $self->get_embedding($query);
        
        return $qdrant->search_points(
            collection_name => $collection_name,
            vector => $query_embedding,
            limit => $limit,
            score_threshold => $concept_threshold,
        );
    }

    method get_context_for_prompt($prompt) 
    {
        my $relevant_memories = $self->find_relevant_memories($prompt);
        my $context = "Previous relevant interactions:\n";

        for my $memory (@{$relevant_memories}) 
        {
            $context .= sprintf(
                "Q: %s\nA: %s\n\n",
                $memory->{payload}{prompt},
                $memory->{payload}{response},
            );
        }

        return $context;
    }

    method extract_concepts($text) 
    {
        try 
        {
            my $response = $ollama->generate(
                prompt => "Extract key concepts from this text, return as comma-separated list: $text",
                options => {
                    temperature => 0.3,
                    top_p => 0.1,
                }
            );

            my @concepts = split(/\s*,\s*/, $response->{response});

            return \@concepts;
        }

        catch ($e) 
        {
            my @words = split(/\s+/, $text);

            return [grep { length($_) > 4 } @words];
        }
    }
}

1; 