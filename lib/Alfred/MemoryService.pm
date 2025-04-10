package Alfred::MemoryService;

use v5.38;
use strict;
use warnings;
use feature 'class';
use feature 'try';
use feature 'signatures';

use Alfred::OllamaClient;

no warnings 'experimental::class';
no warnings 'experimental::try';
no warnings 'experimental::signatures';

class Alfred::MemoryService 
{
    field $ollama :param;
    field $memory_storage = {};
    field $concept_threshold = 0.7;
    field $max_memories = 100;

    ADJUST 
    {
        $ollama //= Alfred::OllamaClient->new;
    }

    method store_prompt($prompt, $response) 
    {
        my $concepts = $self->extract_concepts($prompt);
        my $memory = {
            prompt => $prompt,
            response => $response,
            concepts => $concepts,
            timestamp => time(),
        };

        push @{$self->{memory_storage}{memories}}, $memory;


        if (@{$self->{memory_storage}{memories}} > $self->{max_memories}) 
        {
            shift @{$self->{memory_storage}{memories}};
        }

        return $memory;
    }

    method extract_concepts($text) 
    {
        try {
            # Use Ollama to extract key concepts
            my $response = $self->{ollama}->generate(
                prompt => "Extract key concepts from this text, return as comma-separated list: $text",
                options => {
                    temperature => 0.3,
                    top_p => 0.1,
                }
            );

            my @concepts = split(/\s*,\s*/, $response->{response});
            return \@concepts;
        }
        catch ($e) {
            # Fallback to simple word extraction if Ollama fails
            my @words = split(/\s+/, $text);
            return [grep { length($_) > 4 } @words];
        }
    }

    method find_relevant_memories($query, $limit = 5) 
    {
        my $query_concepts = $self->extract_concepts($query);
        my @relevant_memories;

        for my $memory (@{$self->{memory_storage}{memories}}) {
            my $similarity = $self->calculate_similarity($query_concepts, $memory->{concepts});
            if ($similarity >= $self->{concept_threshold}) {
                push @relevant_memories, {
                    memory => $memory,
                    similarity => $similarity
                };
            }
        }

        # Sort by similarity and limit results
        @relevant_memories = sort { $b->{similarity} <=> $a->{similarity} } @relevant_memories;
        return [@relevant_memories[0..$limit-1]];
    }

    method calculate_similarity($concepts1, $concepts2) 
    {
        my %set1 = map { lc($_) => 1 } @$concepts1;
        my %set2 = map { lc($_) => 1 } @$concepts2;

        my $intersection = 0;
        for my $concept (keys %set1) {
            $intersection++ if exists $set2{$concept};
        }

        my $union = scalar(keys %set1) + scalar(keys %set2) - $intersection;
        return $union > 0 ? $intersection / $union : 0;
    }

    method get_context_for_prompt($prompt) 
    {
        my $relevant_memories = $self->find_relevant_memories($prompt);
        my $context = "Previous relevant interactions:\n";

        for my $memory (@$relevant_memories) {
            $context .= sprintf(
                "Q: %s\nA: %s\n\n",
                $memory->{memory}{prompt},
                $memory->{memory}{response}
            );
        }

        return $context;
    }
}

1; 