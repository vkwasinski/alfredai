use v5.40;
use strict;
use warnings;

use Test::More;
use Test::Exception;

use FindBin qw($Bin);
use lib "$Bin/../lib";

use Alfred::OllamaClient;
use Alfred::HttpClient;

# Mock HttpClient
{
    package MockHttpClient;
    sub new { bless {}, shift }
    sub post {
        my ($self, $url, $data) = @_;
        return {
            response => "Mock response for: " . $data->{prompt},
            embedding => [0.1, 0.2, 0.3]  # Mock embedding
        };
    }
}

# Override the real module
BEGIN {
    *Alfred::HttpClient:: = *MockHttpClient::;
}

# Test cases
subtest 'OllamaClient construction' => sub {
    my $client;
    lives_ok { $client = Alfred::OllamaClient->new } 'can create new client';
    isa_ok($client, 'Alfred::OllamaClient', 'client is correct type');
};

subtest 'generate method' => sub {
    my $client = Alfred::OllamaClient->new;
    my $response;
    
    lives_ok { 
        $response = $client->generate(
            prompt => "Test prompt",
            model => "llama2",
            options => {
                temperature => 0.7
            }
        )
    } 'can generate response';
    
    like(
        $response->{response},
        qr/Mock response for: Test prompt/,
        'response contains prompt'
    );
};

subtest 'list_models method' => sub {
    my $client = Alfred::OllamaClient->new;
    my $models;
    
    lives_ok { 
        $models = $client->list_models()
    } 'can list models';
    
    isa_ok($models, 'HASH', 'returns hash reference');
};

subtest 'chat method' => sub {
    my $client = Alfred::OllamaClient->new;
    my $response;
    
    lives_ok { 
        $response = $client->chat(
            model => "llama2",
            messages => [
                { role => "user", content => "Hello" }
            ]
        )
    } 'can chat';
    
    like(
        $response->{response},
        qr/Mock response for:/,
        'response is generated'
    );
};

done_testing; 