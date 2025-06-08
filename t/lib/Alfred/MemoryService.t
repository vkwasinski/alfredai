use strict;
use warnings;
use Test::More;

use Alfred::MemoryService;

# Mock data stores
my %mock_qdrant_calls;
my %mock_ollama_calls;
my $mock_qdrant_points_count = 0;
my @mock_qdrant_points_list;

# --- Mocking Alfred::OllamaClient ---
{
    no warnings 'redefine';
    local *Alfred::OllamaClient::new = sub ($class, %args) {
        $mock_ollama_calls{'new'}++;
        my $self = bless {}, $class;
        # Store args if needed for assertions
        $self->{args} = \%args;
        return $self;
    };

    local *Alfred::OllamaClient::generate = sub ($self, %args) {
        $mock_ollama_calls{'generate'}++;
        $mock_ollama_calls{'generate_args'} = \%args; # Store last call args

        # Return dummy embedding for prompts asking for embedding
        if ($args{options}{embedding}) {
            return { embedding => [0.1, 0.2, 0.3] };
        }
        # Return dummy concepts for prompts asking for concepts
        return { response => "mock_concept1, mock_concept2" };
    };
}

# --- Mocking Qdrant::Client ---
{
    no warnings 'redefine';
    local *Qdrant::Client::new = sub ($class, %args) {
        $mock_qdrant_calls{'new'}++;
        my $self = bless {}, $class;
        $self->{args} = \%args;
        return $self;
    };

    local *Qdrant::Client::create_collection = sub ($self, %args) {
        $mock_qdrant_calls{'create_collection'}++;
        $mock_qdrant_calls{'create_collection_args'} = \%args;
        # Qdrant create_collection can throw an error if collection exists,
        # or succeed. For tests, we usually want it to succeed silently or mock behavior.
        # Returning a true value to indicate success.
        return { status => "ok", result => \1 };
    };

    local *Qdrant::Client::get_collection_info = sub ($self, %args) {
        $mock_qdrant_calls{'get_collection_info'}++;
        $mock_qdrant_calls{'get_collection_info_args'} = \%args;
        return {
            result => {
                points_count => $mock_qdrant_points_count
            }
        };
    };

    local *Qdrant::Client::list_points = sub ($self, %args) {
        $mock_qdrant_calls{'list_points'}++;
        $mock_qdrant_calls{'list_points_args'} = \%args;
        # Return a slice of @mock_qdrant_points_list based on limit/offset if needed
        # For now, returns the whole list or a predefined slice
        my $limit = $args{limit} || 10;
        my $offset_id = $args{offset}; # In Qdrant, offset for scroll can be a point ID

        my @points_to_return;
        if (defined $offset_id) {
            my $idx = 0;
            $idx++ while $idx < @mock_qdrant_points_list && $mock_qdrant_points_list[$idx]->{id} ne $offset_id;
            # If offset_id found, start from next point. If not, or if it's the last, return empty.
            # This is a simplified mock; real scroll is more complex.
            # For these tests, we'll likely control @mock_qdrant_points_list directly.
            # For now, just return a limited set from the start if offset is not handled simply.
            @points_to_return = @mock_qdrant_points_list[0 .. ($limit-1)]; # Simplified
        } else {
            @points_to_return = @mock_qdrant_points_list[0 .. ($limit-1)]; # Simplified
        }
        @points_to_return = grep { defined $_ } @points_to_return;


        return {
            result => {
                points => \@points_to_return,
                # next_page_offset => ... # Can be added if pagination mock is needed
            }
        };
    };

    local *Qdrant::Client::delete_points = sub ($self, %args) {
        $mock_qdrant_calls{'delete_points'}++;
        $mock_qdrant_calls{'delete_points_args'} = \%args;
        # Simulate point deletion by filtering @mock_qdrant_points_list
        # or just acknowledge call for now.
        my $ids_to_delete = $args{point_ids} || [];
        my %delete_map = map { $_ => 1 } @$ids_to_delete;
        @mock_qdrant_points_list = grep { !$delete_map{$_->{id}} } @mock_qdrant_points_list;
        $mock_qdrant_points_count = scalar @mock_qdrant_points_list;
        return { status => "ok", result => { operation_id => 0, status => "completed" } };
    };

    local *Qdrant::Client::upsert_points = sub ($self, %args) {
        $mock_qdrant_calls{'upsert_points'}++;
        $mock_qdrant_calls{'upsert_points_args'} = \%args;
        # Simulate point upsert by adding to @mock_qdrant_points_list
        my $points_to_add = $args{points} || [];
        push @mock_qdrant_points_list, @$points_to_add; # Simplified; assumes no actual upsert logic needed for mock
        $mock_qdrant_points_count = scalar @mock_qdrant_points_list;
        return { status => "ok", result => { operation_id => 0, status => "completed" } };
    };
}

sub reset_mocks {
    %mock_qdrant_calls = ();
    %mock_ollama_calls = ();
    $mock_qdrant_points_count = 0;
    @mock_qdrant_points_list = ();
}

# --- Test Cases ---

# Test Case 1: Default Initialization
reset_mocks();
my $mem_service_default = Alfred::MemoryService->new();
isa_ok($mem_service_default, 'Alfred::MemoryService', 'Service creation with defaults');
is($mem_service_default->{max_memories}, 1000, 'Default max_memories is 1000');
is($mem_service_default->{pruning_batch_size}, 50, 'Default pruning_batch_size is 50');
ok($mock_ollama_calls{'new'}, 'OllamaClient constructor called');
ok($mock_qdrant_calls{'new'}, 'QdrantClient constructor called');
ok($mock_qdrant_calls{'create_collection'}, 'QdrantClient::create_collection called during init');
is($mock_qdrant_calls{'create_collection_args'}{collection_name}, 'memories', 'Default collection name is "memories"');

# Test Case 2: Initialization with Custom Parameters
reset_mocks();
my $mem_service_custom = Alfred::MemoryService->new(
    max_memories => 500,
    pruning_batch_size => 20
);
isa_ok($mem_service_custom, 'Alfred::MemoryService', 'Service creation with custom params');
is($mem_service_custom->{max_memories}, 500, 'Custom max_memories is set');
is($mem_service_custom->{pruning_batch_size}, 20, 'Custom pruning_batch_size is set');
ok($mock_qdrant_calls{'create_collection'}, 'QdrantClient::create_collection called during custom init');

# Test Case 3: Initialization with custom clients (Optional - if we want to ensure they are used)
reset_mocks();
my $mock_o = bless {}, 'Alfred::OllamaClient'; # Simpler mock object
my $mock_q = bless {}, 'Qdrant::Client';

# Redefine new for this specific test if we want to check if *these instances* are used.
# However, the current MemoryService ADJUST block will call new on the class if undef.
# So, to test if *passed instances* are used, we'd need to check $mem_service->{ollama} == $mock_o.
# For now, checking if our new() mocks aren't called when instances are passed is enough.
$mock_ollama_calls{'new'} = 0; # Reset counter
$mock_qdrant_calls{'new'} = 0; # Reset counter

my $mem_service_with_clients = Alfred::MemoryService->new(
    ollama => $mock_o,
    qdrant => $mock_q
);
isa_ok($mem_service_with_clients, 'Alfred::MemoryService', 'Service creation with passed client instances');
is($mock_ollama_calls{'new'}, 0, 'OllamaClient constructor NOT called when instance provided');
is($mock_qdrant_calls{'new'}, 0, 'QdrantClient constructor NOT called when instance provided');
# Check if the provided instances are actually stored
is($mem_service_with_clients->{ollama}, $mock_o, 'Provided ollama instance is used');
is($mem_service_with_clients->{qdrant}, $mock_q, 'Provided qdrant instance is used');
ok($mock_qdrant_calls{'create_collection'}, 'QdrantClient::create_collection still called with provided qdrant instance');

# --- Pruning Test Cases ---

subtest "Memory storage up to limit (no pruning)" => sub {
    reset_mocks();
    my $max_mem = 3;
    my $pbs = 2; # pruning_batch_size
    my $mem_service = Alfred::MemoryService->new(max_memories => $max_mem, pruning_batch_size => $pbs);

    for my $i (1 .. $max_mem) {
        # Set point count *before* this store_prompt call
        $mock_qdrant_points_count = $i - 1;
        # Ensure the list reflects this count for consistency if list_points were called (it shouldn't be here)
        @mock_qdrant_points_list = map { { id => "p$_", payload => { timestamp => 100 + $_ } } } (1 .. ($i-1));

        $mem_service->store_prompt("prompt $i", "response $i");

        ok($mock_qdrant_calls{'upsert_points'}, "upsert_points called for point $i");
        is($mock_qdrant_calls{'delete_points'}, undef, "delete_points NOT called for point $i");
        is($mock_qdrant_points_count, $i, "Mock points count is $i after storing point $i");
        $mock_qdrant_calls{'upsert_points'} = 0; # Reset for next iteration's check
    }
};

subtest "Pruning when limit is first exceeded" => sub {
    reset_mocks();
    my $max_mem = 3;
    my $pbs = 2;
    my $mem_service = Alfred::MemoryService->new(max_memories => $max_mem, pruning_batch_size => $pbs);

    # 1. Fill memory up to max_memories
    for my $i (1 .. $max_mem) {
        $mock_qdrant_points_count = $i - 1;
        @mock_qdrant_points_list = map { +{ id => "p$_", payload => { timestamp => 100 + $_ } } } (1 .. ($i-1));
        $mem_service->store_prompt("prompt $i", "response $i"); # This updates @mock_qdrant_points_list internally
    }
    # At this point, @mock_qdrant_points_list = (p1, p2, p3), $mock_qdrant_points_count = 3
    is($mock_qdrant_points_count, $max_mem, "Memory filled up to max_memories limit");
    $mock_qdrant_calls{'delete_points'} = 0; # Ensure it wasn't called yet

    # 2. Store one more point (max_memories + 1)-th point overall. This should NOT trigger pruning yet with current logic.
    # $mock_qdrant_points_count is already 3 (reflects state before this call)
    $mem_service->store_prompt("prompt ".($max_mem + 1), "response ".($max_mem+1));
    ok($mock_qdrant_calls{'upsert_points'}, "upsert_points called for point ".($max_mem + 1));
    is($mock_qdrant_calls{'delete_points'}, 0, "delete_points NOT called when storing point ".($max_mem + 1));
    is($mock_qdrant_points_count, $max_mem + 1, "Points count is max_memories + 1");
    # @mock_qdrant_points_list = (p1, p2, p3, p4)

    # 3. Store another point (max_memories + 2)-th point overall. THIS call should trigger pruning.
    # $mock_qdrant_points_count is now $max_mem + 1, which is > $max_mem
    my $expected_point_ids_to_delete = [ map { "p$_" } (1 .. $pbs) ]; # p1, p2 (oldest $pbs points)

    $mem_service->store_prompt("prompt ".($max_mem + 2), "response ".($max_mem+2));

    ok($mock_qdrant_calls{'upsert_points'}, "upsert_points called for point ".($max_mem + 2));
    ok($mock_qdrant_calls{'list_points'}, "list_points WAS called for pruning");
    ok($mock_qdrant_calls{'delete_points'}, "delete_points WAS called for pruning");

    my $deleted_args = $mock_qdrant_calls{'delete_points_args'};
    isa_ok($deleted_args->{point_ids}, 'ARRAY', "point_ids for deletion is an arrayref");
    is_deeply([sort @{$deleted_args->{point_ids}}], [sort @$expected_point_ids_to_delete],
              "Correct oldest $pbs points were deleted");

    # Expected final count: ($max_mem + 1 initially for this step) - $pbs (deleted) + 1 (newly added)
    # ($max_mem + 1) was $mock_qdrant_points_count when store_prompt was called.
    # Pruning logic: num_actually_over_limit = ($max_mem + 1) - $max_mem = 1.
    # num_to_delete = max($pbs, 1) = $pbs. So $pbs points deleted.
    # Final count in mock DB: ($max_mem + 1) - $pbs + 1.
    is($mock_qdrant_points_count, ($max_mem + 1) - $pbs + 1, "Final points count after pruning and adding");
};


subtest "Pruning: num_actually_over_limit < pruning_batch_size" => sub {
    reset_mocks();
    my $max_mem = 10;
    my $pbs = 5; # pruning_batch_size
    my $mem_service = Alfred::MemoryService->new(max_memories => $max_mem, pruning_batch_size => $pbs);

    # Setup: 11 points in DB (1 over limit)
    my $initial_count = $max_mem + 1;
    @mock_qdrant_points_list = map { +{ id => "p$_", payload => { timestamp => 100 + $_ } } } (1 .. $initial_count);
    $mock_qdrant_points_count = $initial_count;

    # num_actually_over_limit = 11 - 10 = 1
    # num_to_delete = max(pbs(5), 1) = 5. So, 5 points should be deleted.
    my $expected_ids_to_delete = [ map { "p$_" } (1 .. $pbs) ]; # p1 to p5

    $mem_service->store_prompt("prompt ".($initial_count+1), "response ".($initial_count+1)); # Store 12th point overall

    ok($mock_qdrant_calls{'delete_points'}, "delete_points was called");
    my $deleted_args = $mock_qdrant_calls{'delete_points_args'};
    is_deeply([sort @{$deleted_args->{point_ids}}], [sort @$expected_ids_to_delete],
              "Correct $pbs points deleted (num_over_limit < pbs)");

    # Initial: 11. Deleted: 5. Added: 1. Final: 11 - 5 + 1 = 7
    is($mock_qdrant_points_count, $initial_count - $pbs + 1, "Final points count is correct");
};

subtest "Pruning: num_actually_over_limit >= pruning_batch_size" => sub {
    reset_mocks();
    my $max_mem = 10;
    my $pbs = 2; # pruning_batch_size
    my $mem_service = Alfred::MemoryService->new(max_memories => $max_mem, pruning_batch_size => $pbs);

    # Setup: 13 points in DB (3 over limit)
    my $initial_count = $max_mem + 3;
    @mock_qdrant_points_list = map { +{ id => "p$_", payload => { timestamp => 100 + $_ } } } (1 .. $initial_count);
    $mock_qdrant_points_count = $initial_count;

    # num_actually_over_limit = 13 - 10 = 3
    # num_to_delete = max(pbs(2), 3) = 3. So, 3 points should be deleted.
    my $num_expected_to_delete = 3;
    my $expected_ids_to_delete = [ map { "p$_" } (1 .. $num_expected_to_delete) ]; # p1 to p3

    $mem_service->store_prompt("prompt ".($initial_count+1), "response ".($initial_count+1)); # Store 14th point overall

    ok($mock_qdrant_calls{'delete_points'}, "delete_points was called");
    my $deleted_args = $mock_qdrant_calls{'delete_points_args'};
    is_deeply([sort @{$deleted_args->{point_ids}}], [sort @$expected_ids_to_delete],
              "Correct $num_expected_to_delete points deleted (num_over_limit >= pbs)");

    # Initial: 13. Deleted: 3. Added: 1. Final: 13 - 3 + 1 = 11
    is($mock_qdrant_points_count, $initial_count - $num_expected_to_delete + 1, "Final points count is correct");
};

done_testing();
