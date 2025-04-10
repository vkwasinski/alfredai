package Alfred::OllamaClient;

use v5.38;
use strict;
use warnings;
use feature 'class';
use feature 'signatures';
use Alfred::HttpClient;
use Alfred::Config;

no warnings 'experimental::class';
no warnings 'experimental::signatures';

class OllamaClient 
{
    field $config :param = Alfred::Config->new;
    field $http_client :param = Alfred::HttpClient->new;

    ADJUST 
    {
        $config = Alfred::Config->new unless $config;
        $http_client = Alfred::HttpClient->new unless $http_client;
    }

    method generate (%params) 
    {
        return $http_client->post(
            $config->get_base_url . "/api/generate",
            {
                model => $params{model} // $config->get_default_model,
                prompt => $params{prompt},
                stream => $params{stream} // $config->get_stream,
                options => {
                    %{$config->get_options},
                    %{$params{options} // {}}
                }
            },
            'Content-Type' => 'application/json'
        );
    }

    method list_models () 
    {
        return $http_client->get(
            $config->get_base_url . "/api/tags",
            'Content-Type' => 'application/json'
        );
    }

    method chat (%params) 
    {
        return $http_client->post(
            $config->get_base_url . "/api/chat",
            {
                model => $params{model} // $config->get_default_model,
                messages => $params{messages},
                stream => $params{stream} // $config->get_stream,
                options => {
                    %{$config->get_options},
                    %{$params{options} // {}}
                }
            },
            'Content-Type' => 'application/json'
        );
    }
}

1;

__END__

=head1 NAME

Alfred::OllamaClient - Client for Ollama API

=head1 SYNOPSIS

    use Alfred::OllamaClient;
    
    my $ollama = Alfred::OllamaClient->new();
    my $response = $ollama->generate(
        model => 'llama2',
        prompt => 'Write a haiku about programming'
    );

=head1 DESCRIPTION

Client for interacting with the Ollama API.

=cut 