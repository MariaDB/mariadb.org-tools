
CREATE TABLE tbl ( id INT PRIMARY KEY NOT NULL AUTO_INCREMENT, val TEXT, updated DATETIME NOT NULL ON UPDATE CURRENT_TIMESTAMP);

INSERT INTO tbl (val) VALUES ('dog'),('cat'), ('kangaroo'), ('possum'), ('quoll'), ('quokka');
