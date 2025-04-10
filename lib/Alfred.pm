package Alfred;

use v5.38;
use strict;
use warnings;

our $VERSION = '0.01';

1;

__END__

=head1 NAME

Alfred - Perl client for Ollama API

=head1 SYNOPSIS

    use Alfred;
    my $ollama = Alfred::OllamaClient->new();
    
    my $response = $ollama->generate(
        model => 'llama2',
        prompt => 'Write a haiku about programming'
    );

=head1 DESCRIPTION

Alfred is a Perl client for interacting with the Ollama API.

=head1 AUTHOR

Your Name <your.email@example.com>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut 