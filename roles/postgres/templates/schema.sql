CREATE OR REPLACE FUNCTION canonize(_text text)
    RETURNS text
    LANGUAGE sql
    IMMUTABLE
AS $$
    SELECT lower(trim($1));
$$;

CREATE TABLE address_types (
    type        text not null,
    description text not null,

    PRIMARY KEY (type)
);
INSERT INTO address_types (type, description) VALUES
    ('alias',   'An alias address defined for a user'),
    ('list',    'A mailing list');

CREATE TABLE users (
   username  text not null,
   password  text not null,
   name      text not null,
   login     boolean not null default true,
   active    boolean not null default true,

   PRIMARY KEY (username)
);
CREATE UNIQUE INDEX users_username_canon_idx ON users (canonize(username));

CREATE OR REPLACE FUNCTION validate_target(_target text, _type text)
    RETURNS boolean
    LANGUAGE plpgsql
AS $$
BEGIN
    IF strpos(_target, '@') > 0 THEN
        RETURN true;
    END IF;

    PERFORM 1 FROM users WHERE canonize(username) = canonize(_target);
    RETURN FOUND;
END
$$;

CREATE TABLE user_addresses (
    address  text not null,
    domain   text not null,
    target   text not null,
    spamuser text not null,
    type     text not null default 'alias',

    CHECK (validate_target(target, type)),

    PRIMARY KEY (address, domain, target),
    FOREIGN KEY (type) REFERENCES address_types (type)
);
CREATE UNIQUE INDEX user_addresses_uniq_address_idx ON user_addresses (address, domain) WHERE type <> 'list';

CREATE TYPE user_address AS (
    address  text,
    domain   text,
    target   text,
    spamuser text,
    type     text
);

CREATE OR REPLACE FUNCTION find_user_address(_full_address text)
    RETURNS SETOF user_address
    LANGUAGE plpgsql
AS $$
DECLARE
    _user_part       text;
    _domain_part     text;
    _user_part_array text[];
    _tmp             text;
BEGIN
    SELECT canonize(split_part(_full_address, '@', 1)) INTO _user_part;
    SELECT canonize(split_part(_full_address, '@', 2)) INTO _domain_part;

    PERFORM 1 FROM user_addresses WHERE address = _user_part AND domain = _domain_part;
    IF FOUND THEN
        RETURN QUERY SELECT address, domain, target, spamuser, type FROM user_addresses WHERE address = _user_part AND domain = _domain_part;
        RETURN;
    END IF;

    SELECT regexp_split_to_array(_user_part,'-')       INTO _user_part_array;

    FOR _i IN REVERSE array_length(_user_part_array, 1)..1 LOOP
        _tmp := array_to_string(_user_part_array[0:_i],'-') || '-default';

        PERFORM 1 FROM user_addresses WHERE address = _tmp AND domain = _domain_part;
        IF FOUND THEN
            RETURN QUERY SELECT address, domain, target, spamuser, type FROM user_addresses WHERE address = _tmp AND domain = _domain_part;
            RETURN;
        END IF;
    END LOOP;

    RETURN QUERY SELECT address, domain, target, spamuser, type FROM user_addresses WHERE address = '@default' AND domain = _domain_part;
END;
$$;

CREATE OR REPLACE FUNCTION mailtarget(_full_address text)
    RETURNS SETOF user_address
    LANGUAGE plpgsql
AS $$
DECLARE
    _target     user_address;
    _old_target user_address;
    _new_target user_address;
BEGIN
    RETURN QUERY
        SELECT
            address,
            domain,
            CASE
                WHEN strpos(target, '@') = 0 THEN target || '@localdelivery'
                ELSE target
            END AS target,
            spamuser,
            type
        FROM find_user_address(_full_address);
    RETURN;
END;
$$;

CREATE OR REPLACE FUNCTION disable_user(_username text, _active boolean DEFAULT false, _login boolean DEFAULT false)
    RETURNS boolean
    LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE users
    SET
        active = COALESCE(_active, false),
        login  = COALESCE(_login, false)
    WHERE canonize(username) = canonize(_username);

    RETURN FOUND;
END;
$$;

CREATE TABLE dkim (
   domain_name text not null,
   selector    text not null,
   private_key text,
   public_key  text,

   PRIMARY KEY (domain_name)
);

GRANT SELECT ON user_addresses, users, address_types TO rfc822_dovecot;
GRANT SELECT ON user_addresses, users, address_types TO rfc822_postfix;
GRANT SELECT ON user_addresses, users, address_types TO rfc822_spamd;
GRANT SELECT ON dkim TO rfc822_opendkim;
