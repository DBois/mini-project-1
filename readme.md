# Mini Project 1: SQL Databases V2

This project contains our proposed solution to the [first Mini Project described here.](https://datsoftlyngby.github.io/soft2020spring/resources/d3821340-MP1-2.pdf)

## a) formulating specifications

We have formulated the specifications by answering all of the following points.

## b) creating appropriate data model

From the business requirments we created the following ER diagram:  
![](./img/Mini_projekt_1_ER_Diagram.png)

## c) creating and populating the database with sufficient test data

To create and populate the database run the following script which can be [downloaded here.](./populate_tables.sql)  
We have also split the different sql queries into parts to make it more readable. These files can be found in this repository.

## d) programming the requested functionality in SQL

The requested functionality as described by the business requirements are as follows:  
Search and retrieve information such as, but not limited to:

1. current availability of a specific book  
   To get the availability of a specific book we have created the following function:

```sql
CREATE OR REPLACE FUNCTION book_available(param_book_id integer)
 RETURNS TABLE(isbn character varying, available boolean, title varchar(256), edition integer, publisher varchar(256), published date, pages integer, description text)
 LANGUAGE plpgsql
AS $function$ 
begin
	return query select bi.isbn, cbt.returned as available, bi.title, bi.edition, bi.publisher, bi.published, bi.pages, bi.description
    from book as b
    JOIN client_book_transaction as cbt on cbt.book_id = b.id
    JOIN book_info as bi ON bi.isbn = b.book_info_isbn
    where cbt.id = (select max(id) from client_book_transaction where book_id = param_book_id);
end;
$function$
;

```


To get the availability from the function, the following query should be called:  
`select * from book_available(ID);`  
where ID is the ID of the book you want to get the availability for.  

2. most popular book title among high scool students in a specific period of time.  
   To get the most popular book for students over a specific period of a time we have created the following function which returns a table with the data:

```sql
DROP FUNCTION IF EXISTS most_popular_book(date,date);

CREATE OR REPLACE FUNCTION most_popular_book(start_date date, end_date date)
RETURNS TABLE
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
    where cbt.loan_date > '2019-01-01'
    and cbt.loan_date < '2020-08-08' and c.role_id = 3) as st
    group by st.isbn, st.title
    order by ct desc limit 1;
end;
$$
language plpgsql;
```

3. notifications about delayed returning of a book over the due time.
   We have created the following view to get all books that are overdue:

```sql
drop view if exists overdue_books;

create or replace view overdue_books as
    select c.id as client_id, cbt.returned, cbt.return_date, bi.isbn, bi.title, bi.edition, bi.publisher, bi.published, bi.pages, bi.description
    from client as c
    JOIN client_book_transaction as cbt on cbt.client_id=c.id
    JOIN book as b on b.id = cbt.book_id
    JOIN book_info as bi ON bi.isbn = b.book_info_isbn
    where cbt.returned = 'f'
    and cbt.return_date < current_date;
```

In addition to the requested features we implemented these:

1. Search for a book by book name  
   We created the following function to search for a book by using a tsquery.

```sql
DROP FUNCTION IF EXISTS find_book;
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
```

To use this function to search for books, use the following query:  
`SELECT * FROM find_book('Day')`

## e) add constrains reflecting the business rules

According to the business requirements the following contraints were implemented:

1. Books can be ordered and borrowed by registered clients, only.

   We created a role called unregistered which we assume will be used if no user have been logged in from the frontend. This role has only **SELECT** privilege on the book and book_info tables. Which means they can only search for books. For registered users we have created the client role which is allowed to loan books. For more detailed **ROLE** and **USER** overview,
   read the last section i).

2. The allowable loan period, as well as the number of books in a loan can vary. (For example, students can loan maximum three books at a time, teachers can have up to two, while other borrowers can take just one)

   We created the following function for when books are to be loaned:

```sql
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
```

In this function we check how the current amount of books the client has compares to the book loan limit on the role.

## f) add constrains ensuring referential integrity

When referring to rows in other tables we always use the primary key from the referred table as a foreign key. As we do not **DELETE** rows from our tables, **CASCADE** is not needed.

## g) keeping transactions ACID and protected against blocking and deadlocks

For all of our **INSERT** and **UPDATE** queries we use the default isolation level for Postgres **READ COMMITTED** which prevents dirty reads.  
Whenever you want to read from tables you should use the SERIALIZABLE isolation level, to ensure you have consistent data.

```sql
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
BEGIN TRANSACTION;
SELECT * FROM find_book('Harry Potter');
COMMIT;
```

## h) considering optimization of the queries

We have not added any indexes as it did not improve the performance of the queries. However this could be due to the sample data being too small and PostgreSQL selecting sequential search as a faster option. We have tested the following index:  
`create index isbn_index on book(book_info_isbn);`  
**Before indexing:**  
![](./img/index1.png)  
**After indexing:**
![](./img/index2.png)

## i) protecting the use of the database with user account management, and control of privileges.

### Roles and permissions

We have created four roles:

<table>
    <tr>
        <th>Role</th>
        <th>role (table)</th>
        <th>client</th>
        <th>book</th>
        <th>book_info</th>
        <th>author</th>
        <th>book_info_author</th>
        <th>client_book_transaction</th>
    </tr>
    <tr>
        <td>unregistered</td> <role>
        <td></td> 
        <td></td> 
        <td>SELECT</td> 
        <td>SELECT</td> 
        <td></td> 
        <td></td> <book_info_author>
        <td></td> 
    </tr>
    <tr>
        <td>client</td> <role>
        <td></td> 
        <td>SELECT, UPDATE</td> 
        <td>SELECT</td> 
        <td>SELECT, UPDATE</td> 
        <td></td> 
        <td></td> <book_info_author>
        <td>INSERT, SELECT, UPDATE</td> 
    </tr>
    <tr>
        <td>worker</td> <role>
        <td>SELECT</td> 
        <td>SELECT, UPDATE</td> 
        <td>INSERT, SELECT, DELETE, UPDATE</td> 
        <td>INSERT, SELECT, DELETE, UPDATE</td> 
        <td>SELECT</td> 
        <td>SELECT</td> <book_info_author>
        <td>INSERT, SELECT, UPDATE</td> 
    </tr>
    <tr>
        <td>admin</td> <role>
        <td>CRUD</td> 
        <td>CRUD</td> 
        <td>CRUD</td> 
        <td>CRUD</td> 
        <td>CRUD</td> 
        <td>CRUD</td> <book_info_author>
        <td>CRUD</td> 
    </tr>
</table>

### Additional permissions:

**client**: **EXECUTE** the loan_book function. **SELECT** on **SEQUENCE** client_book_transaction_id_seq.  
**worker**: **SELECT** on all tables. **INSERT, DELETE, UPDATE** on book, book_info. **SELECT** on **SEQUENCE** book_id_seq.  
**admin**: **PRIVILEGES** on all sequences.

### Users

Aditionally we have created three users with encrypted passwords:  
**Username**: unregistered_user **Password**: 1234  
**Username**: client_user **Password**: Passw0rd  
**Username**: worker_user **Password**: Passw0rd  
**Username**: admin_user **Password**: Admin
