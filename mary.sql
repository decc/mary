-- SQL for POSTGRES
CREATE DATABASE mary;
\c mary;

CREATE TABLE assumptions
(
  -- These bits identify an assumption uniquely and permanently. 
  -- Every edit to the table will result in a new set of these values.
  -- i.e., if the assumption is that the 2050 load factor on nuclear power
  -- will be 20%, and I later change it to 21%, the uid will change.
  -- this allows someone to always find out what an assumption used to be
  uid serial primary key, -- i.e., 1, 2, 3
  created_at timestamp DEFAULT current_timestamp, -- i.e., 12/April/2013
  created_by text DEFAULT current_user, -- i.e., tom.counsell@decc.gsi.gov.uk
  deleted bool DEFAULT FALSE, -- This is used to prevent this assumption from appearing in latest_assumptions

  -- A unique reference number for this assumption.
  -- This won't change if the value change.
  -- i.e., in the example above, the number will remain the same
  -- even after the load factor assumption has been revised.
  -- it can be used to access the latest version of any given assumption.
  aid serial NOT NULL, -- i.e., 1, 2, 3 ...
  UNIQUE (aid, uid),

  -- Specifies what kind of assumption we are entering
  category text NOT NULL, -- i.e., Nuclear Power
  parameter text NOT NULL,  -- i.e., Capital Cost, Load Factor

  -- Specifies this specific assumption's provenance
  source text NOT NULL, -- i.e., Markal 3.26
  label text, -- EPWR

  -- Specifies this specific assumption, in the format entered
  original_value text, -- 3 TWh, £1000/kW
  original_period text, -- 2007, Jan 2007, heating year 2007

  -- A normalised version of the assumption. The unit should be the same
  -- across all assumptions that share the same category and name.
  value decimal, -- 3000
  unit text, -- MWh
  period tsrange -- 00:00 1/01/2007 to 23:59 31/12/2007
); 

CREATE INDEX uid_index ON assumptions (uid);
CREATE INDEX aid_index ON assumptions (aid);
CREATE INDEX category_lowercase_index ON asssumptions (lower(category));
CREATE INDEX name_lowercase_index ON asssumptions (lower(name));
CREATE INDEX label_lowercase_index ON asssumptions (lower(label));
CREATE INDEX aid_uid_ordered_index ON assumptions (aid ASC, uid DESC);

CREATE VIEW latest_assumptions_including_deleted AS 
  SELECT DISTINCT ON (aid) * 
  FROM assumptions
  ORDER BY aid, uid DESC;

CREATE VIEW latest_assumptions AS
  SELECT *
  FROM latest_assumptions_including_deleted
  WHERE NOT deleted;

CREATE TABLE notes
(
  id serial primary key, -- i.e., a unique id
  assumption_aid integer, -- if set, then this note will appear with all versions of an assumption (mainly used for comments)
  assumption_uid integer REFERENCES assumptions(uid) ON DELETE CASCADE, -- if set, then this note will appear with just one version of an assumption (mainly used for warnings and history)
  created_at timestamp DEFAULT current_timestamp, -- i.e., 12/April/2013
  created_by text DEFAULT current_user, -- i.e., tom.counsell@decc.gsi.gov.uk
  content text NOT NULL-- i.e., the actual comment "We are assuming the currency is in 2010 pounds"
);


