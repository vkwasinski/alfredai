package Alfred::Config;

use v5.38;
use strict;
use warnings;
use feature 'class';
use feature 'signatures';
use Dotenv -load;

no warnings 'experimental::class';
no warnings 'experimental::signatures';

class Config 
{
    field $base_url = $ENV{OLLAMA_BASE_URL} // 'http://localhost:11434';
    field $default_model = $ENV{OLLAMA_DEFAULT_MODEL} // 'llama2';
    field $stream = $ENV{OLLAMA_STREAM} // 0;
    field $temperature = $ENV{OLLAMA_TEMPERATURE} // 0.7;
    field $top_p = $ENV{OLLAMA_TOP_P} // 0.9;
    field $top_k = $ENV{OLLAMA_TOP_K} // 40;

    method get_base_url () 
    {
        return $base_url;
    }

    method get_default_model () 
    {
        return $default_model;
    }

    method get_stream () 
    {
        return $stream;
    }

    method get_options () 
    {
        return {
            temperature => $temperature,
            top_p => $top_p,
            top_k => $top_k
        };
    }
}

1;

__END__

=head1 NAME

Alfred::Config - Configuration handler for Alfred

=head1 DESCRIPTION

Handles environment variables and configuration settings for the Alfred module.

=cut 