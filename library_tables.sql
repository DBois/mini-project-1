DROP TABLE IF EXISTS author, book_info, book_info_author, book, client_book_transaction, client, role;
drop view if exists book_transaction, book_transaction;

CREATE TABLE role (
    id serial PRIMARY KEY,
    name varchar(50),
    loan_days int,
    book_limit int
);

CREATE TABLE client (
    id serial PRIMARY KEY,
    role_id int REFERENCES role(id) NOT NULL,
    name varchar(128),
    password varchar(128),
    adress varchar(128),
	no_books INT DEFAULT 0
);

CREATE TABLE author(
	id serial PRIMARY KEY,
	name VARCHAR(128)
);

CREATE TABLE book_info(
	isbn VARCHAR(13) PRIMARY KEY,
	title VARCHAR(256) NOT NULL,
	edition INT,
	publisher VARCHAR(256),
	published DATE,
	pages INT,
	description TEXT,
	avail_printed INT,
	avail_electronic INT,
	avail_rare INT
);

CREATE TABLE book_info_author(
	author_id INT REFERENCES  author (id) NOT NULL,
	isbn VARCHAR(13) REFERENCES book_info (isbn) NOT NULL
);

CREATE TABLE book(
	id SERIAL PRIMARY KEY,
	is_printed BOOLEAN DEFAULT 'f',
	is_electronic BOOLEAN DEFAULT 'f',
	is_rare BOOLEAN DEFAULT 'f',
	book_info_isbn VARCHAR(13) REFERENCES book_info (isbn) NOT NULL
);

CREATE TABLE client_book_transaction(
id SERIAL PRIMARY KEY,
	client_id INT REFERENCES client (id) NOT NULL,
	book_id INT REFERENCES book (id) NOT NULL,
	loan_date DATE NOT NULL,
	return_date DATE NOT NULL,
	returned BOOLEAN DEFAULT 'f'
);

create or replace view book_transaction as
select c.id as client_id, bi.isbn, bi.title, bi.edition, bi.publisher, bi.published, bi.pages, bi.description
from client as c
join client_book_transaction as cbt on c.id = cbt.client_id 
JOIN book as b on cbt.book_id = b.id 
JOIN book_info as bi ON b.book_info_isbn  = bi.isbn;

create or replace view book_transaction as
select c.id as client_id, bi.isbn, bi.title, bi.edition, bi.publisher, bi.published, bi.pages, bi.description
from client as c
JOIN client_book_transaction as cbt on cbt.client_id=c.id 
JOIN book as b on b.id = cbt.book_id 
JOIN book_info as bi ON bi.isbn = b.book_info_isbn 
where cbt.returned = 'f';