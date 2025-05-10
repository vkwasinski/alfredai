package Alfred::MemoryService;

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

use Carp qw/croak/;

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

    field $DISTANCE = 'Cosine';

    ADJUST 
    {
        $ollama //= Alfred::OllamaClient->new;
        $qdrant //= Qdrant::Client->new;
        
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