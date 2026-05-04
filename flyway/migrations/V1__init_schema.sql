-- V1: Club database schema (cd schema)
-- Source: pgexercises.com clubdata dataset
-- Stripped: CREATE DATABASE / \c commands (Flyway connects to the configured DB directly)

CREATE SCHEMA IF NOT EXISTS cd;

SET search_path = cd, pg_catalog;

CREATE TABLE facilities (
    facid    integer NOT NULL,
    name     character varying(100) NOT NULL,
    membercost       numeric NOT NULL,
    guestcost        numeric NOT NULL,
    initialoutlay    numeric NOT NULL,
    monthlymaintenance numeric NOT NULL
);

CREATE TABLE members (
    memid    integer NOT NULL,
    surname  character varying(200) NOT NULL,
    firstname        character varying(200) NOT NULL,
    address  character varying(300) NOT NULL,
    zipcode  integer NOT NULL,
    telephone        character varying(20) NOT NULL,
    recommendedby    integer,
    joindate timestamp without time zone NOT NULL
);

CREATE TABLE bookings (
    bookid   integer NOT NULL,
    facid    integer NOT NULL,
    memid    integer NOT NULL,
    starttime        timestamp without time zone NOT NULL,
    slots    integer NOT NULL
);

ALTER TABLE ONLY bookings
    ADD CONSTRAINT bookings_pk PRIMARY KEY (bookid);

ALTER TABLE ONLY facilities
    ADD CONSTRAINT facilities_pk PRIMARY KEY (facid);

ALTER TABLE ONLY members
    ADD CONSTRAINT members_pk PRIMARY KEY (memid);

ALTER TABLE ONLY bookings
    ADD CONSTRAINT fk_bookings_facid FOREIGN KEY (facid) REFERENCES facilities(facid);

ALTER TABLE ONLY bookings
    ADD CONSTRAINT fk_bookings_memid FOREIGN KEY (memid) REFERENCES members(memid);

ALTER TABLE ONLY members
    ADD CONSTRAINT fk_members_recommendedby FOREIGN KEY (recommendedby) REFERENCES members(memid) ON DELETE SET NULL;

CREATE INDEX "bookings.memid_facid"      ON cd.bookings USING btree (memid, facid);
CREATE INDEX "bookings.facid_memid"      ON cd.bookings USING btree (facid, memid);
CREATE INDEX "bookings.facid_starttime"  ON cd.bookings USING btree (facid, starttime);
CREATE INDEX "bookings.memid_starttime"  ON cd.bookings USING btree (memid, starttime);
CREATE INDEX "bookings.starttime"        ON cd.bookings USING btree (starttime);
CREATE INDEX "members.joindate"          ON cd.members  USING btree (joindate);
CREATE INDEX "members.recommendedby"     ON cd.members  USING btree (recommendedby);
