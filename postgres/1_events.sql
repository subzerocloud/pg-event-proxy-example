drop schema if exists events cascade;
create schema events;
grant usage on schema events to public;

create table events.events (
    id    serial primary key,
    channel  text not null,
    message  text not null,
    created_on   timestamptz not null default now() 
);


create or replace function events.send_message(
  channel text,
  message text,
  routing_key text default '',
  durable boolean default false,
  skip_flush boolean default false) returns void as
$$
declare
  proxy record;
begin
  if not durable then
    perform pg_notify(channel,  routing_key || '|' || message );
  else
    select pid from pg_stat_activity where application_name = 'pg-event-proxy' into proxy;
    if proxy is null then
        insert into events.events (channel, message) values (channel, routing_key || '|' || message);
    else
        if not skip_flush then
            perform events.flush();
        end if;
        perform pg_notify(channel,  routing_key || '|' || message );
    end if;
  end if;
end;
$$ volatile language plpgsql;

create or replace function events.flush() returns void as
$$
declare
    event record;
begin
    for event in select id, channel, message from events.events order by created_on asc for update skip locked
    loop
        perform pg_notify(event.channel,  event.message );
        delete from events.events where id = event.id;
    end loop;
end
$$ volatile language plpgsql;


create or replace function events.on_row_change() returns trigger as $$
  declare
    channel text;
    routing_key text;
    row jsonb;
    config jsonb;
    excluded_columns text[];
    col text;
  begin
    -- we use the '.user-10.' part of the routing key to select which user should be able to receive these events.
    routing_key := 'row_change'
                   '.table-'::text || TG_TABLE_NAME::text || 
                   '.event-'::text || TG_OP::text;
    if (TG_OP = 'DELETE') then
        row := row_to_json(old)::jsonb;
    elsif (TG_OP = 'UPDATE') then
        row := row_to_json(new)::jsonb;
    elsif (TG_OP = 'INSERT') then
        row := row_to_json(new)::jsonb;
    end if;

    if ( TG_NARGS > 0 ) then
        channel := TG_ARGV[0];
    else
        channel := 'events';
    end if;
    -- decide what row columns to send based on the config parameter
    -- there is a 8000 byte hard limit on the payload size so sending many big columns is not possible
    if ( TG_NARGS = 2 ) then
      config := TG_ARGV[1];
      if (config ? 'include') then
          --excluded_columns := ARRAY(SELECT unnest(jsonb_object_keys(row)::text[]) EXCEPT SELECT unnest( array(select jsonb_array_elements_text(config->'include')) ));
          -- this is a diff between two arrays
          excluded_columns := array(
            -- array of all row columns
            select unnest(
              array(select jsonb_object_keys(row))
            ) 
            except
            -- array of included columns
            select unnest(
              array(select jsonb_array_elements_text(config->'include'))
            )
          );
      end if;

      if (config ? 'exclude') then
        excluded_columns := array(select jsonb_array_elements_text(config->'exclude'));
      end if;

      if (current_setting('server_version_num')::int >= 100000) then
          row := row - excluded_columns;
      else
          FOREACH col IN ARRAY excluded_columns
          LOOP
            row := row - col;
          END LOOP;
      end if;
    end if;
    
    perform events.send_message(channel, row::text, routing_key, true);
    return null;
  end;
$$ stable language plpgsql;

