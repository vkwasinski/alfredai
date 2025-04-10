use 5.038;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => 'Alfred',
    VERSION_FROM => 'lib/Alfred.pm',
    PREREQ_PM    => {
        'LWP::UserAgent' => 0,
        'JSON'           => 0,
        'HTTP::Request'  => 0,
    },
    ABSTRACT     => 'Perl client for Ollama API',
    AUTHOR       => 'Your Name <vkwasinski@gmail.com>',
); 
