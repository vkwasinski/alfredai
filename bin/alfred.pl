#!/usr/bin/env perl

use v5.40;
use strict;
use warnings;

use Data::Dumper;

use feature 'class';
use feature 'try';
use feature 'signatures';

use FindBin qw/$Bin/;
use lib "$Bin/../lib";

use Dotenv -load;

use Alfred::OllamaClient;
use Alfred::MemoryService;

no warnings 'experimental::class';
no warnings 'experimental::try';
no warnings 'experimental::signatures';

my $ollama = Alfred::OllamaClient->new;
my $memory = Alfred::MemoryService->new(ollama => $ollama);

try 
{
    my $prompt = $ARGV[0];
    
    my $context = $memory->get_context_for_prompt($prompt);
    
    my $response = $ollama->generate(
        prompt => "$context\nUser: $prompt\nAssistant:"
    );
    
    $memory->store_prompt($prompt, $response->{response});
    
    say "Response: " . $response->{response};
    
    my $relevant_memories = $memory->find_relevant_memories($prompt);

    if (@{$relevant_memories}) 
    {
        say 'Relevant previous interactions: ';

        for my $mem (@{$relevant_memories}) 
        {
            say sprintf(
                "Similarity: %.2f\nQ: %s\nA: %s",
                $mem->{similarity},
                $mem->{memory}{prompt},
                $mem->{memory}{response}
            );
        }
    }
}

catch ($e) 
{
    print "Error: $e\n";
}
