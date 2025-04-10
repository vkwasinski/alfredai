package Alfred::HttpClient;

use v5.38;
use strict;
use warnings;
use feature 'class';
use feature 'signatures';
use LWP::UserAgent;
use JSON;
use HTTP::Request;

no warnings 'experimental::class';
no warnings 'experimental::signatures';

class HttpClient 
{
    field $ua :param = LWP::UserAgent->new;
    field $json :param = JSON->new->utf8(1);

    ADJUST 
    {
        $ua = LWP::UserAgent->new unless $ua;
        $json = JSON->new->utf8(1) unless $json;
    }

    method get ($url, %headers) 
    {
        my $request = HTTP::Request->new(
            'GET',
            $url,
            [%headers]
        );
        
        return $self->_make_request($request);
    }

    method post ($url, $data, %headers) 
    {
        my $request = HTTP::Request->new(
            'POST',
            $url,
            [%headers],
            $json->encode($data)
        );
        
        return $self->_make_request($request);
    }

    method _make_request ($request) 
    {
        my $response = $ua->request($request);
        
        if ($response->is_success) 
        {
            return $json->decode($response->content);
        }
        
        die "HTTP request failed: " . $response->status_line;
    }
}

1;

__END__

=head1 NAME

Alfred::HttpClient - HTTP client for Alfred

=head1 DESCRIPTION

Internal HTTP client used by Alfred for making API requests.

=cut 