DROP PROCEDURE IF EXISTS most_popular_book, return_book, loan_book;
DROP FUNCTION IF EXISTS most_popular_book, find_book;
DROP TRIGGER IF EXISTS book_counter ON book CASCADE;

CREATE OR REPLACE FUNCTION book_counter() RETURNS trigger AS $$
BEGIN
	CASE NEW.book_type
		WHEN 'rare' THEN
			UPDATE book_info SET avail_rare=avail_rare+1 WHERE isbn=NEW.book_info_isbn;
		WHEN 'printed' THEN
			UPDATE book_info SET avail_printed=avail_printed+1 WHERE isbn=NEW.book_info_isbn;
		WHEN 'electronic' THEN
			UPDATE book_info SET avail_electronic=avail_electronic+1 WHERE isbn=NEW.book_info_isbn;
	END CASE;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER book_counter AFTER INSERT on book FOR EACH ROW EXECUTE PROCEDURE book_counter();

CREATE OR REPLACE PROCEDURE loan_book(client_id integer, book_id integer)
 LANGUAGE plpgsql
AS $procedure$
DECLARE 
    client_no_books integer;
    role_book_limit integer;
    var_book_type text;
    var_loan_days integer;
    
BEGIN 
    SELECT no_books INTO client_no_books FROM client c WHERE c.id=client_id;
    SELECT book_limit INTO role_book_limit FROM role r JOIN client c ON c.role_id=r.id AND c.id=client_id;
    SELECT book_type INTO var_book_type FROM book b WHERE b.id=book_id;
    SELECT loan_days INTO var_loan_days FROM role r JOIN client c ON c.id=client_id AND c.role_id=r.id;
    
    IF client_no_books < role_book_limit THEN 
        
        UPDATE client SET no_books=no_books+1 WHERE client.id=client_id;
        CASE var_book_type
            WHEN 'printed'
                THEN UPDATE book_info SET avail_printed=avail_printed-1 FROM book WHERE book_info.isbn=book.book_info_isbn; 
            WHEN 'electronic'
                THEN UPDATE book_info SET avail_electronic=avail_electronic-1 FROM book WHERE book_info.isbn=book.book_info_isbn;
            WHEN 'rare'
                THEN UPDATE book_info SET avail_rare=avail_rare-1 FROM book WHERE book_info.isbn=book.book_info_isbn;
        END CASE;
        INSERT INTO client_book_transaction (client_id, book_id, loan_date, return_date) VALUES (client_id, book_id, CURRENT_DATE, CURRENT_DATE + (var_loan_days * INTERVAL '1 day'));
        RAISE NOTICE 'Loan successful';
    ELSE
        RAISE EXCEPTION 'Client book limit exceeded max book limit of %', role_book_limit
          USING HINT = 'Please return books to loan more';
    
    END IF;
END;
$procedure$
;

CREATE OR REPLACE PROCEDURE return_book(param_book_id integer)
 LANGUAGE plpgsql
AS $procedure$
DECLARE 
    var_book_type text;
    var_transaction_id integer;
    var_client_id integer;
    var_book_isbn text;
    var_returned boolean;

BEGIN 
    SELECT book_type INTO var_book_type FROM book WHERE id=param_book_id;
    SELECT id, client_id, returned INTO var_transaction_id, var_client_id, var_returned FROM client_book_transaction cbt WHERE book_id=3 and cbt.id = (select max(id) from CLIENT_BOOK_TRANSACTION);    
    select book_info_isbn into var_book_isbn from book where id=param_book_id;
    
       if var_returned = false THEN
        UPDATE client SET no_books=no_books-1 WHERE client.id=var_client_id;
        CASE var_book_type
            WHEN 'printed'
                THEN UPDATE book_info SET avail_printed=avail_printed+1 FROM book WHERE book_info.isbn = var_book_isbn; 
            WHEN 'electronic'
                THEN UPDATE book_info SET avail_electronic=avail_electronic+1 FROM book WHERE book_info.isbn = var_book_isbn;
            WHEN 'rare'
                THEN UPDATE book_info SET avail_rare=avail_rare+1 FROM book WHERE book_info.isbn = var_book_isbn;
        END CASE;
        
        UPDATE client_book_transaction SET returned = true WHERE client_id=var_client_id;
    
    else
        RAISE EXCEPTION 'Book already returned';
    end if;
    
    
END;
$procedure$
;

CREATE OR REPLACE PROCEDURE addbook(
    param_author_name VARCHAR, param_isbn VARCHAR, param_title VARCHAR, param_edition INTEGER, 
    param_publisher VARCHAR, param_published DATE, param_pages INTEGER, param_description text
    ) AS $$
    DECLARE
        param_author_id INTEGER;
        any_author_found INTEGER;
        any_isbn_found INTEGER;
    BEGIN 
        SELECT count(*) INTO any_author_found FROM author WHERE name = param_author_name;
        SELECT count(*) INTO any_isbn_found FROM book_info WHERE isbn = param_isbn;
        
        IF any_isbn_found = 1 THEN
            -- If isbn already exists
            RAISE EXCEPTION '% - Already exists', param_isbn
                USING HINT = 'Please enter another ISBN';
        END IF;    
    
        IF any_author_found = 1 THEN
            -- If author already exists
            SELECT id INTO param_author_id FROM author WHERE name = param_author_name; 
            INSERT INTO book_info(isbn, title, edition, publisher, published, pages, description) 
                VALUES (param_isbn, param_title, param_edition, param_publisher, param_published, param_pages, param_description);
            INSERT INTO book_info_author(author_id, isbn) 
                VALUES (param_author_id, param_isbn);
        ELSE
            -- Creates author if non existing
            SELECT setval(pg_get_serial_sequence('author','id'), (SELECT max(id) FROM author)) INTO param_author_id;
            INSERT INTO author(id, name) 
                VALUES (param_author_id +1, param_author_name);
            INSERT INTO book_info(isbn, title, edition, publisher, published, pages, description)
                VALUES (param_isbn, param_title, param_edition, param_publisher, param_published, param_pages, param_description);
            INSERT INTO book_info_author(author_id, isbn) 
                VALUES (param_author_id +1, param_isbn);
        END IF;
    END;
$$ LANGUAGE plpgsql;

create or replace function find_book(str varchar)
returns table 
(
    isbn varchar(13),
    title varchar(256),
    edition int,
    publisher varchar(256),
    published date,
    description text,
    avail_printed int,
    avail_electronic int,
    avail_rare int
) as $$
begin
        return query select 
            bi.isbn, 
            bi.title,
            bi.edition, 
            bi.publisher,
            bi.published, 
            bi.description, 
            bi.avail_electronic,
            bi.avail_printed, 
            bi.avail_rare
        from book_info bi
    where bi.title @@ str;
end;
$$ language 'plpgsql';

CREATE OR REPLACE function most_popular_book(start_date date, end_date date)
returns table 
(
    ct bigint,
    title varchar(256),
    isbn varchar(13)
) as $$ 
begin
    return query select count(st.isbn) as ct, st.title, st.isbn from 
    (select bi.title, bi.isbn from book_info as bi
    join book b ON b.book_info_isbn = bi.isbn
    join client_book_transaction cbt on cbt.book_id = b.id
    join client c on cbt.client_id = c.id 
    where cbt.loan_date > '2019-01-01' and cbt.loan_date < '2020-08-08' and c.role_id = 3) as st 
group by st.isbn, st.title
order by ct desc limit 1; 
end;
$$
language plpgsql