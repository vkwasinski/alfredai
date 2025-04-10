#!/usr/bin/env perl

use v5.38;
use strict;
use warnings;
use Data::Dumper;
use feature 'class';
use feature 'try';
use feature 'signatures';

# Add the lib directory to @INC
use FindBin qw($Bin);
use lib "$Bin/../lib";

# Load environment variables
use Dotenv -load;

use Alfred::OllamaClient;
use Alfred::MemoryService;

no warnings 'experimental::class';
no warnings 'experimental::try';
no warnings 'experimental::signatures';

my $ollama = Alfred::OllamaClient->new;
my $memory = Alfred::MemoryService->new(ollama => $ollama);

try {
    my $prompt = $ARGV[0];
    
    my $context = $memory->get_context_for_prompt($prompt);
    
    my $response = $ollama->generate(
        prompt => "$context\nUser: $prompt\nAssistant:"
    );
    
    $memory->store_prompt($prompt, $response->{response});
    
    print "Response: " . $response->{response} . "\n";
    
    my $relevant_memories = $memory->find_relevant_memories($prompt);
    if (@$relevant_memories) {
        print "\nRelevant previous interactions:\n";
        for my $mem (@$relevant_memories) {
            print sprintf(
                "Similarity: %.2f\nQ: %s\nA: %s\n\n",
                $mem->{similarity},
                $mem->{memory}{prompt},
                $mem->{memory}{response}
            );
        }
    }
}
catch ($e) {
    print "Error: $e\n";
}

try {
    my $models = $ollama->list_models();
    print "Available models:\n";
    print Dumper($models);
}

catch ($e) 
{
    print "Error: $e\n";
}

# Example 3: Chat conversation
try {
    my $chat_response = $ollama->chat(
        messages => [
            {
                role => 'user',
                content => $ARGV[0],
            }
        ]
    );

    print "Chat response: " . $chat_response->{response} . "\n";

} 

catch ($e) 
{
    print "Error: $e\n";
}