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
	s_time TIMESTAMP,
	e_time TIMESTAMP,
	int_time INTEGER);
	



COPY nation FROM '/home/mariadb/benchmark/dbt3/gen_data/s30/nation.tbl' USING DELIMITERS '|';
COPY region FROM '/home/mariadb/benchmark/dbt3/gen_data/s30/region.tbl' USING DELIMITERS '|';
COPY supplier FROM '/home/mariadb/benchmark/dbt3/gen_data/s30/supplier.tbl' USING DELIMITERS '|';
COPY part FROM '/home/mariadb/benchmark/dbt3/gen_data/s30/part.tbl' USING DELIMITERS '|';
COPY customer FROM '/home/mariadb/benchmark/dbt3/gen_data/s30/customer.tbl' USING DELIMITERS '|';
COPY orders FROM '/home/mariadb/benchmark/dbt3/gen_data/s30/orders.tbl' USING DELIMITERS '|';
COPY partsupp FROM '/home/mariadb/benchmark/dbt3/gen_data/s30/partsupp.tbl' USING DELIMITERS '|';
COPY lineitem FROM '/home/mariadb/benchmark/dbt3/gen_data/s30/lineitem.tbl' USING DELIMITERS '|';


/*
ALTER TABLE supplier
ADD CONSTRAINT pk_supplier PRIMARY KEY (s_suppkey);

ALTER TABLE part
ADD CONSTRAINT pk_part PRIMARY KEY (p_partkey);

ALTER TABLE partsupp
ADD CONSTRAINT pk_partsupp PRIMARY KEY (ps_partkey, ps_suppkey);

ALTER TABLE customer
ADD CONSTRAINT pk_customer PRIMARY KEY (c_custkey);

ALTER TABLE orders
ADD CONSTRAINT pk_orders PRIMARY KEY (o_orderkey);

ALTER TABLE lineitem
ADD CONSTRAINT pk_lineitem PRIMARY KEY (l_orderkey, l_linenumber);

ALTER TABLE nation
ADD CONSTRAINT pk_nation PRIMARY KEY (n_nationkey);

ALTER TABLE region
ADD CONSTRAINT pk_region PRIMARY KEY (r_regionkey);

*/


CREATE INDEX i_l_shipdate
ON lineitem (l_shipdate);

CREATE INDEX i_l_suppkey_partkey
ON lineitem (l_partkey, l_suppkey);

CREATE INDEX i_l_partkey
ON lineitem (l_partkey);

CREATE INDEX i_l_suppkey
ON lineitem (l_suppkey);

CREATE INDEX i_l_receiptdate
ON lineitem (l_receiptdate);

CREATE INDEX i_l_orderkey
ON lineitem (l_orderkey);

CREATE INDEX i_l_orderkey_quantity
ON lineitem (l_orderkey, l_quantity);

CREATE INDEX i_c_nationkey
ON customer (c_nationkey);

CREATE INDEX i_o_orderdate
ON orders (o_orderdate);

CREATE INDEX i_o_custkey
ON orders (o_custkey);

CREATE INDEX i_s_nationkey
ON supplier (s_nationkey);

CREATE INDEX i_ps_partkey
ON partsupp (ps_partkey);

CREATE INDEX i_ps_suppkey
ON partsupp (ps_suppkey);

CREATE INDEX i_n_regionkey
ON nation (n_regionkey);

CREATE INDEX i_l_commitdate
ON lineitem (l_commitdate);



ANALYZE supplier;
ANALYZE part;
ANALYZE partsupp;
ANALYZE customer;
ANALYZE orders;
ANALYZE lineitem;
ANALYZE nation;
ANALYZE region;