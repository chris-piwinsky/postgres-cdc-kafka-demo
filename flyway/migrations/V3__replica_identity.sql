-- V3: Enable REPLICA IDENTITY FULL for CDC (Debezium)
-- Required so UPDATE and DELETE events include the full before-image row.
-- Applied to members and facilities (the tables used in the demo).
-- Bookings omitted from the demo connector but included here for completeness.

ALTER TABLE cd.members    REPLICA IDENTITY FULL;
ALTER TABLE cd.facilities REPLICA IDENTITY FULL;
ALTER TABLE cd.bookings   REPLICA IDENTITY FULL;
