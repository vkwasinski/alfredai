use v5.40;
use strict;
use warnings;

use Test::More;
use Test::Exception;
use Alfred::HttpClient;

# Mock HTTP::Request and LWP::UserAgent
{
    package MockHTTP::Request;
    sub new { bless {}, shift }
    sub method { shift->{method} }
    sub uri { shift->{uri} }
    sub headers { shift->{headers} }
    sub content { shift->{content} }

    package MockLWP::UserAgent;
    sub new { bless {}, shift }
    sub request {
        my ($self, $request) = @_;
        return bless {
            is_success => 1,
            content => '{"test": "data"}',
            status_line => '200 OK'
        }, 'MockHTTP::Response';
    }

    package MockHTTP::Response;
    sub is_success { shift->{is_success} }
    sub content { shift->{content} }
    sub status_line { shift->{status_line} }
}

# Override the real modules
BEGIN {
    *HTTP::Request:: = *MockHTTP::Request::;
    *LWP::UserAgent:: = *MockLWP::UserAgent::;
}

# Test cases
subtest 'HttpClient construction' => sub {
    my $client;
    lives_ok { $client = Alfred::HttpClient->new } 'can create new client';
    isa_ok($client, 'Alfred::HttpClient', 'client is correct type');
};

subtest 'GET request' => sub {
    my $client = Alfred::HttpClient->new;
    my $response;
    
    lives_ok { 
        $response = $client->get(
            'http://test.com',
            'Content-Type' => 'application/json'
        )
    } 'can make GET request';
    
    is_deeply(
        $response,
        { test => 'data' },
        'response is correctly decoded'
    );
};

subtest 'POST request' => sub {
    my $client = Alfred::HttpClient->new;
    my $response;
    
    lives_ok { 
        $response = $client->post(
            'http://test.com',
            { test => 'data' },
            'Content-Type' => 'application/json'
        )
    } 'can make POST request';
    
    is_deeply(
        $response,
        { test => 'data' },
        'response is correctly decoded'
    );
};

subtest 'Error handling' => sub {
    my $client = Alfred::HttpClient->new;
    
    # Mock a failed request
    {
        package MockLWP::UserAgent;
        sub request {
            return bless {
                is_success => 0,
                status_line => '404 Not Found'
            }, 'MockHTTP::Response';
        }
    }
    
    throws_ok {
        $client->get('http://test.com')
    } qr/HTTP request failed: 404 Not Found/,
    'throws on failed request';
};

done_testing; 