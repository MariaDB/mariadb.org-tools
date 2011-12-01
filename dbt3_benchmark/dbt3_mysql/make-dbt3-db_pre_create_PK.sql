DROP DATABASE IF EXISTS dbt3;

SET sql_mode='NO_ENGINE_SUBSTITUTION';

CREATE DATABASE dbt3;

USE dbt3;

CREATE TABLE supplier (
  s_suppkey  INTEGER PRIMARY KEY,
  s_name CHAR(25),
  s_address VARCHAR(40),
  s_nationkey INTEGER,
  s_phone CHAR(15),
  s_acctbal REAL,
  s_comment VARCHAR(101));

CREATE TABLE part (
  p_partkey INTEGER PRIMARY KEY,
  p_name VARCHAR(55),
  p_mfgr CHAR(25),
  p_brand CHAR(10),
  p_type VARCHAR(25),
  p_size INTEGER,
  p_container CHAR(10),
  p_retailprice REAL,
  p_comment VARCHAR(23));

CREATE TABLE partsupp (
  ps_partkey INTEGER,
  ps_suppkey INTEGER,
  ps_availqty INTEGER,
  ps_supplycost REAL,
  ps_comment VARCHAR(199),
  PRIMARY KEY (ps_partkey, ps_suppkey));

CREATE TABLE customer (
  c_custkey INTEGER primary key,
  c_name VARCHAR(25),
  c_address VARCHAR(40),
  c_nationkey INTEGER,
  c_phone CHAR(15),
  c_acctbal REAL,
  c_mktsegment CHAR(10),
  c_comment VARCHAR(117));

CREATE TABLE orders (
  o_orderkey INTEGER primary key,
  o_custkey INTEGER,
  o_orderstatus CHAR(1),
  o_totalprice REAL,
  o_orderDATE DATE,
  o_orderpriority CHAR(15),
  o_clerk CHAR(15),
  o_shippriority INTEGER,
  o_comment VARCHAR(79));

CREATE TABLE lineitem (
  l_orderkey INTEGER,
  l_partkey INTEGER,
  l_suppkey INTEGER,
  l_linenumber INTEGER,
  l_quantity REAL,
  l_extendedprice REAL,
  l_discount REAL,
  l_tax REAL,
  l_returnflag CHAR(1),
  l_linestatus CHAR(1),
  l_shipDATE DATE,
  l_commitDATE DATE,
  l_receiptDATE DATE,
  l_shipinstruct CHAR(25),
  l_shipmode CHAR(10),
  l_comment VARCHAR(44),
  PRIMARY KEY (l_orderkey, l_linenumber));

CREATE TABLE nation (
  n_nationkey INTEGER primary key,
  n_name CHAR(25),
  n_regionkey INTEGER,
  n_comment VARCHAR(152));

CREATE TABLE region (
  r_regionkey INTEGER primary key,
  r_name CHAR(25),
  r_comment VARCHAR(152));

CREATE TABLE time_statistics (
	task_name VARCHAR(40),
	timest TIMESTAMP);



INSERT INTO time_statistics (task_name, timest) VALUES ('loading database started', now());

LOAD DATA INFILE '/home/mariadb/benchmark/dbt3/gen_data/s30/nation.tbl' into table nation fields terminated by '|';
INSERT INTO time_statistics (task_name, timest) VALUES ('load nation table', now());

LOAD DATA INFILE '/home/mariadb/benchmark/dbt3/gen_data/s30/region.tbl' into table region fields terminated by '|';
INSERT INTO time_statistics (task_name, timest) VALUES ('load region table', now());

LOAD DATA INFILE '/home/mariadb/benchmark/dbt3/gen_data/s30/supplier.tbl' into table supplier fields terminated by '|';
INSERT INTO time_statistics (task_name, timest) VALUES ('load supplier table', now());

LOAD DATA INFILE '/home/mariadb/benchmark/dbt3/gen_data/s30/part.tbl' into table part fields terminated by '|';
INSERT INTO time_statistics (task_name, timest) VALUES ('load part table', now());

LOAD DATA INFILE '/home/mariadb/benchmark/dbt3/gen_data/s30/customer.tbl' into table customer fields terminated by '|';
INSERT INTO time_statistics (task_name, timest) VALUES ('load customer table', now());

LOAD DATA INFILE '/home/mariadb/benchmark/dbt3/gen_data/s30/orders.tbl' into table orders fields terminated by '|';
INSERT INTO time_statistics (task_name, timest) VALUES ('load orders table', now());

LOAD DATA INFILE '/home/mariadb/benchmark/dbt3/gen_data/s30/partsupp.tbl' into table partsupp fields terminated by '|';
INSERT INTO time_statistics (task_name, timest) VALUES ('load partsupp table', now());

LOAD DATA INFILE '/home/mariadb/benchmark/dbt3/gen_data/s30/lineitem.tbl' into table lineitem fields terminated by '|';
INSERT INTO time_statistics (task_name, timest) VALUES ('load lineitem table', now());



ALTER TABLE lineitem 
   ADD INDEX i_l_shipdate(l_shipdate),
   ADD INDEX i_l_suppkey_partkey (l_partkey, l_suppkey),
   ADD INDEX i_l_partkey (l_partkey),
   ADD INDEX i_l_suppkey (l_suppkey),
   ADD INDEX i_l_receiptdate (l_receiptdate),
   ADD INDEX i_l_orderkey (l_orderkey),
   ADD INDEX i_l_orderkey_quantity (l_orderkey, l_quantity),
   ADD INDEX i_l_commitdate (l_commitdate);
INSERT INTO time_statistics (task_name, timest) VALUES ('added lineitem indexes', now());

CREATE INDEX i_c_nationkey ON customer (c_nationkey);
INSERT INTO time_statistics (task_name, timest) VALUES ('added customer indexes', now());

ALTER TABLE orders
  ADD INDEX i_o_orderdate (o_orderdate),
  ADD INDEX i_o_custkey (o_custkey);
INSERT INTO time_statistics (task_name, timest) VALUES ('added orders indexes', now());

CREATE INDEX i_s_nationkey ON supplier (s_nationkey);
INSERT INTO time_statistics (task_name, timest) VALUES ('added supplier indexes', now());

ALTER TABLE partsupp 
  ADD INDEX i_ps_partkey (ps_partkey),
  ADD INDEX i_ps_suppkey (ps_suppkey);
INSERT INTO time_statistics (task_name, timest) VALUES ('added partsupp indexes', now());

CREATE INDEX i_n_regionkey ON nation (n_regionkey);
INSERT INTO time_statistics (task_name, timest) VALUES ('added nation indexes', now());

ANALYZE TABLE supplier;
INSERT INTO time_statistics (task_name, timest) VALUES ('analyzed supplier table', now());

ANALYZE TABLE part;
INSERT INTO time_statistics (task_name, timest) VALUES ('analyzed part table', now());

ANALYZE TABLE partsupp;
INSERT INTO time_statistics (task_name, timest) VALUES ('analyzed partsupp table', now());

ANALYZE TABLE customer;
INSERT INTO time_statistics (task_name, timest) VALUES ('analyzed customer table', now());

ANALYZE TABLE orders;
INSERT INTO time_statistics (task_name, timest) VALUES ('analyzed orders table', now());

ANALYZE TABLE lineitem;
INSERT INTO time_statistics (task_name, timest) VALUES ('analyzed lineitem table', now());

ANALYZE TABLE nation;
INSERT INTO time_statistics (task_name, timest) VALUES ('analyzed nation table', now());

ANALYZE TABLE region;
INSERT INTO time_statistics (task_name, timest) VALUES ('analyzed region table', now());
