DROP DATABASE IF EXISTS shareddb;
CREATE DATABASE shareddb;
USE shareddb;

DROP TABLE IF EXISTS tnbs;

CREATE TABLE IF NOT EXISTS tnbs (
    tnb VARCHAR(255) PRIMARY KEY,
    name VARCHAR(255)
);

-- TODO: REMOVE ME
INSERT INTO tnbs (tnb, name) VALUES
                                 ('D001', 'Deutsche Telekom'),
                                 ('V001', 'Vodafone'),
                                 ('O001', 'Orange');