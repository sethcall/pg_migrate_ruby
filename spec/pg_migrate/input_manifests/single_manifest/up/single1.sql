-- this is a SQL comment

select 1;

select 2;

select
3;

create table emp(id BIGSERIAL PRIMARY KEY, name varchar(255));

-- a sql function
CREATE FUNCTION clean_emp() RETURNS void AS '
    DELETE FROM emp;
' LANGUAGE SQL;

-- a sql function on one line
CREATE FUNCTION clean_emp2() RETURNS void AS 'DELETE FROM emp;' LANGUAGE SQL;

CREATE FUNCTION populate() RETURNS integer AS $$
DECLARE
    -- declarations
BEGIN
    PERFORM clean_emp2();
END;
$$ LANGUAGE plpgsql;



