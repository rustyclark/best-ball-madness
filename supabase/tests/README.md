# Database Testing with pgTAP

This project uses `pgTAP` to test the Supabase PostgreSQL database locally.

## Running Tests

To run the database tests, ensure your local Supabase stack is running, then execute:

```bash
supabase test db
```

This command will automatically run all `.sql` files located in the `supabase/tests/` directory.

## Writing Tests

Test files should be placed in `supabase/tests/` and use the `.sql` extension. 
We use the pgTAP framework for assertions.

### Example Test Structure
```sql
BEGIN;

-- 1. Initialize pgTAP
SELECT plan(1); -- specify number of assertions

-- 2. Setup your test data here
-- INSERT INTO public.tournaments (...) VALUES (...);

-- 3. Run assertions
SELECT is(
    (SELECT status FROM public.tournaments LIMIT 1),
    'SCHEDULED',
    'Tournament status should default to SCHEDULED'
);

-- 4. Clean up and finish
SELECT * FROM finish();
ROLLBACK;
```

**Note**: Always wrap your tests in `BEGIN;` and `ROLLBACK;` to ensure the database remains in a clean state after the tests execute.

## References
- [pgTAP Documentation](https://pgtap.org/documentation.html)
- [Supabase Local Testing](https://supabase.com/docs/guides/cli/local-development#database-testing)
