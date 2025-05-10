use v5.40;
use strict;
use warnings;

use File::Basename qw(dirname);
use File::Spec::Functions qw(catdir);

BEGIN {
    my $lib_dir = catdir(dirname(dirname(dirname(__FILE__))), 'lib');
    unshift @INC, $lib_dir;
}

use Test::More;
use Test::Exception;
use feature 'class';
use feature 'signatures';

no warnings 'experimental::class';
no warnings 'experimental::signatures';

use FindBin qw($Bin);
use lib "$Bin/../../../lib";

use Qdrant::Client;
use Alfred::HttpClient;

# Mock HttpClient
{
    package MockHttpClient;
    sub new { bless {}, shift }
    sub post {
        my ($self, $url, $data) = @_;
        return {
            result => {
                operation_id => 123,
                status => "completed"
            }
        };
    }
    sub get {
        my ($self, $url) = @_;
        return {
            result => {
                points => [
                    {
                        id => 1,
                        vector => [0.1, 0.2, 0.3],
                        payload => { text => "test" }
                    }
                ]
            }
        };
    }
}

# Override the real module
BEGIN {
    *Alfred::HttpClient:: = *MockHttpClient::;
}

# Test cases
subtest 'QdrantClient construction' => sub {
    my $client;
    lives_ok { $client = Qdrant::Client->new } 'can create new client';
    isa_ok($client, 'Qdrant::Client', 'client is correct type');
};

subtest 'create_collection method' => sub {
    my $client = Qdrant::Client->new;
    my $result;
    
    lives_ok { 
        $result = $client->create_collection(
            collection_name => "test_collection",
            vector_size => 3
        )
    } 'can create collection';
    
    is($result->{result}->{status}, "completed", "collection created successfully");
};

subtest 'upsert_points method' => sub {
    my $client = Qdrant::Client->new;
    my $result;
    
    lives_ok { 
        $result = $client->upsert_points(
            collection_name => "test_collection",
            points => [
                {
                    id => 1,
                    vector => [0.1, 0.2, 0.3],
                    payload => { text => "test" }
                }
            ]
        )
    } 'can upsert points';
    
    is($result->{result}->{status}, "completed", "points upserted successfully");
};

subtest 'search_points method' => sub {
    my $client = Qdrant::Client->new;
    my $result;
    
    lives_ok { 
        $result = $client->search_points(
            collection_name => "test_collection",
            vector => [0.1, 0.2, 0.3],
            limit => 1
        )
    } 'can search points';
    
    is(scalar @{$result->{result}->{points}}, 1, "found one point");
    is($result->{result}->{points}->[0]->{payload}->{text}, "test", "correct point found");
};

done_testing; 