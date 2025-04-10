# Alfred - Perl Client for Ollama API

A modern Perl client for interacting with the Ollama API, built with Perl 5.38 features.

## Installation

1. Install dependencies:
```bash
cpan install LWP::UserAgent
cpan install JSON
cpan install HTTP::Request
```

2. Clone the repository:
```bash
git clone https://github.com/yourusername/alfred.git
cd alfred
```

3. Install the module:
```bash
perl Makefile.PL
make
make test
make install
```

## Usage

```perl
use Alfred::OllamaClient;

my $ollama = Alfred::OllamaClient->new();

# Generate text
my $response = $ollama->generate(
    model => 'llama2',
    prompt => 'Write a haiku about programming'
);

# List available models
my $models = $ollama->list_models();

# Chat
my $chat_response = $ollama->chat(
    model => 'llama2',
    messages => [
        {
            role => 'user',
            content => 'What is the capital of France?'
        }
    ]
);
```

## Features

- Modern Perl 5.38 syntax
- Object-oriented design
- Error handling with try/catch
- Full Ollama API support
- Clean and maintainable code

## Requirements

- Perl 5.38 or higher
- Ollama server running locally
- Required Perl modules (see Installation)

## License

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 