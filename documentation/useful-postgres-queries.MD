# Useful Postgres queries

## Connect to Postgres

```bash
docker exec -ti some-postgres psql -U postgres
```

## Verify WAL and replication settings

```sql
SELECT name, setting
FROM pg_settings
WHERE name IN ('wal_level', 'max_wal_senders', 'max_replication_slots');
```

## Check active replication slots

```sql
SELECT slot_name, plugin, database, active, restart_lsn
FROM pg_replication_slots;
```

## Check publications

```sql
SELECT * FROM pg_publication;
SELECT * FROM pg_publication_tables;
```

## Check replica identity on tracked tables

```sql
SELECT relname, relreplident
FROM pg_class
WHERE relname IN ('members', 'facilities', 'bookings');
```

`relreplident` values:

- `d` = default (primary key only)
- `f` = full (all columns)
- `n` = nothing

## Inspect Flyway migration history

```sql
SELECT version, description, success, installed_on
FROM flyway_schema_history
ORDER BY installed_rank;
```

## Inspect table data

```sql
SELECT memid, surname, firstname, address FROM cd.members LIMIT 10;
```

## Insert a test row (produces CDC event)

```sql
INSERT INTO cd.members (memid, surname, firstname, address, zipcode, telephone, recommendedby, joindate)
VALUES (999, 'TestUser', 'Local', '1 Test Street, Boston', 12345, '555-000-0001', NULL, NOW());
```

## Update a row (produces CDC update event)

```sql
UPDATE cd.members SET address = '2 New Street, Boston' WHERE memid = 999;
```
