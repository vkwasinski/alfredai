# Alfred - Perl-based AI Assistant

Alfred is a sophisticated Perl-based AI assistant that leverages the Ollama API to provide intelligent responses with memory capabilities. Built with modern Perl features (5.38+), it offers a robust and extensible framework for AI interactions.

## Features

- **Intelligent Memory System**: Stores and retrieves relevant past interactions using Qdrant vector database
- **Context-Aware Responses**: Generates responses based on previous conversations
- **Concept Extraction**: Automatically identifies key concepts from prompts
- **Configurable**: Easy to customize through environment variables
- **Modern Perl**: Utilizes Perl 5.38+ features including experimental class syntax

## Prerequisites

- Perl 5.38 or higher
- Ollama server running locally or accessible via network
- Qdrant vector database (via Docker)
- Required Perl modules (see Installation)

## Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/alfred.git
cd alfred
```

2. Install dependencies:
```bash
cpan install LWP::UserAgent JSON HTTP::Request Dotenv
```

3. Start Qdrant using Docker:
```bash
docker run -p 6333:6333 \
    -v $(pwd)/qdrant_data:/qdrant/storage \
    qdrant/qdrant
```

4. Configure your environment:
```bash
cp .env.example .env
# Edit .env with your configuration
```

## Configuration

Create a `.env` file with the following settings:

```env
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_DEFAULT_MODEL=llama2
OLLAMA_TEMPERATURE=0.7
OLLAMA_TOP_P=0.9
OLLAMA_MAX_TOKENS=4096

# Qdrant Configuration
QDRANT_HOST=http://localhost
QDRANT_PORT=6333
QDRANT_COLLECTION=memories
QDRANT_VECTOR_SIZE=384
QDRANT_DISTANCE=Cosine
```

## Usage

Run Alfred with a prompt:

```bash
perl bin/alfred.pl "Your question here"
```

## Project Structure

```
alfred/
├── bin/
│   └── alfred.pl          # Main executable
├── lib/
│   └── Alfred/
│       ├── Config.pm      # Configuration management
│       ├── HttpClient.pm  # HTTP client wrapper
│       ├── MemoryService.pm # Memory and concept management
│       ├── OllamaClient.pm # Ollama API client
│       └── Qdrant/
│           └── Client.pm  # Qdrant vector database client
├── .env                   # Environment configuration
└── Makefile.PL           # Build configuration
```

## Components

### MemoryService
- Stores and retrieves conversation history using Qdrant
- Extracts key concepts from prompts
- Calculates similarity between prompts
- Provides context for new queries

### Qdrant Client
- Interfaces with Qdrant vector database
- Manages vector storage and retrieval
- Handles similarity searches
- Configurable distance metrics

### OllamaClient
- Interfaces with Ollama API
- Handles text generation
- Manages model interactions
- Configurable generation parameters

### HttpClient
- Manages HTTP requests
- Handles API communication
- Provides error handling
- Supports custom configurations

### Config
- Centralizes configuration management
- Loads environment variables
- Provides default values
- Validates settings

## Development

1. Install development dependencies:
```bash
cpanm --installdeps .
```

2. Run tests:
```bash
prove -l t/
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Ollama for providing the AI backend
- Qdrant for vector database capabilities
- Perl community for modern language features
- Contributors and maintainers 