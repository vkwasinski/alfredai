package Qdrant::Client;

use v5.40;
use strict;
use warnings;

use feature 'class';
use feature 'signatures';

use Carp qw/carp croak/; # Added croak

use HTTP::Tiny;
use JSON;

no warnings 'experimental::class';
no warnings 'experimental::signatures';

our $VERSION = '0.01';

=head1 NAME

Qdrant::Client - Perl client for Qdrant vector database

=head1 SYNOPSIS

    use Qdrant::Client;
    
    my $client = Qdrant::Client->new(
        host => 'http://localhost',
        port => 6333,
        api_key => 'your-api-key'
    );
    
    # Create a collection
    $client->create_collection(
        collection_name => 'my_collection',
        vector_size => 128,
        distance => 'Cosine'
    );
    
    # Insert points
    $client->upsert_points(
        collection_name => 'my_collection',
        points => [
            {
                id => 1,
                vector => [0.1, 0.2, 0.3],
                payload => { text => 'sample text' }
            }
        ]
    );

=head1 DESCRIPTION

This module provides a Perl interface to the Qdrant vector database API.
It implements the HTTP client for interacting with Qdrant's REST API.

=cut

class Qdrant::Client 
{
    field $host :param = 'http://localhost';
    field $port :param = 6333;
    field $api_key :param;
    field $http :param = HTTP::Tiny->new(timeout => 10, verify_SSL => 1);
    field $json :param = JSON->new->utf8;

    ADJUST 
    {
        $http = HTTP::Tiny->new(timeout => 10, verify_SSL => 1) unless $http;
        $json = JSON->new->utf8 unless $json;
    }

    method create_collection (%params) 
    {
        carp "collection_name is required"
            if !$params{collection_name};

        carp "vector_size is required"
            if !$params{vector_size};
        
        my $payload = {
            vectors => {
                size => $params{vector_size},
                distance => $params{distance} || 'Cosine'
            }
        };
        
        return $self->_request(
            method => 'PUT',
            path   => "/collections/$params{collection_name}",
            data   => $payload
        );
    }

    method delete_points (%params)
    {
        croak "collection_name is required for delete_points"
            unless $params{collection_name};
        croak "point_ids (array ref) is required for delete_points"
            unless $params{point_ids} && ref $params{point_ids} eq 'ARRAY';
        croak "point_ids array cannot be empty for delete_points"
            unless @{$params{point_ids}};

        return $self->_request(
            method => 'POST',
            path   => "/collections/$params{collection_name}/points/delete",
            data   => { points => $params{point_ids} }
        );
    }

    method list_points (%params)
    {
        croak "collection_name is required for list_points"
            unless $params{collection_name};

        my $payload = {
            limit        => $params{limit} || 10,
            with_payload => defined $params{with_payload} ? ($params{with_payload} ? \1 : \0) : \1, # JSON true/false
            with_vector  => defined $params{with_vector}  ? ($params{with_vector}  ? \1 : \0) : \0, # JSON true/false
        };
        $payload->{offset} = $params{offset} if defined $params{offset}; # offset can be a point ID

        # The scroll API returns an object like { result: { points: [], next_page_offset: "..." } }
        # We are interested in the points array.
        my $response = $self->_request(
            method => 'POST',
            path   => "/collections/$params{collection_name}/points/scroll",
            data   => $payload
        );

        # Return the points array, or an empty list if points are not found
        return $response->{result}{points} || [];
    }

    method get_collection_info (%params)
    {
        carp "collection_name is required"
            if !$params{collection_name};

        return $self->_request(
            method => 'GET',
            path   => "/collections/$params{collection_name}"
        );
    }

    method upsert_points (%params) 
    {
        carp "collection_name is required"
            if !$params{collection_name};

        carp "points is required"
            if !$params{points};
        
        return $self->_request(
            method => 'PUT',
            path   => "/collections/$params{collection_name}/points",
            data   => { points => $params{points} }
        );
    }

    method search_points (%params) 
    {
        carp "collection_name is required"
            if !$params{collection_name};

        carp "vector is required"
            if !$params{vector};
        
        my $payload = {
            vector => $params{vector},
            limit  => $params{limit} || 10,
            with_payload => $params{with_payload} // 1,
            with_vector  => $params{with_vector}  // 0
        };
        
        return $self->_request(
            method => 'POST',
            path   => "/collections/$params{collection_name}/points/search",
            data   => $payload
        );
    }

    method delete_collection (%params) 
    {
        carp "collection_name is required"
            if !$params{collection_name};
        
        return $self->_request(
            method => 'DELETE',
            path   => "/collections/$params{collection_name}"
        );
    }

    method _request (%params) 
    {
        my $url = sprintf("%s:%d%s", $host, $port, $params{path});
        
        my %headers = (
            'Content-Type' => 'application/json'
        );
        
        $headers{'api-key'} = $api_key if $api_key;
        
        my $response = $http->request(
            $params{method},
            $url,
            {
                headers => \%headers,
                content => $params{data} ? $json->encode($params{data}) : undef
            }
        );
        
        unless ($response->{success}) 
        {
            carp sprintf(
                "Qdrant request failed: %s - %s",
                $response->{status},
                $response->{content}
            );
        }
        
        return $json->decode($response->{content});
    }
}

1;
