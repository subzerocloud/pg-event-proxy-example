CREATE TABLE IF NOT EXISTS foo (
    id SERIAL PRIMARY KEY,
    name TEXT
);


-- attach the trigger to send events to upstream
-- there is a 8000 bytes hard limit on the message payload size (PG NOTIFY) so it's better not to send data that is not used
-- on_row_change call can take the following forms
-- on_row_change() - send all columns to 'events' channel
-- on_row_change('myevents') - send all columns tp 'myevents' channel
-- on_row_change('myevents', '{"include":["id"]}'::json) - send only the listed columns
-- on_row_change('myevents', '{"exclude":["bigcolumn"]}'::json) - exclude listed columns from the payload

create trigger send_foo_change_events
after insert or update or delete on foo
for each row execute procedure events.on_row_change('myevents', '{"include":["id","name"]}');