DROP PROCEDURE SHOPIFY.NEW_ORDERS;

CREATE PROCEDURE SHOPIFY.NEW_ORDERS ()
LANGUAGE SQL

BEGIN

set schema SHOPIFY;

CREATE TABLE SHOPIFY.testclob(jsondoc CLOB CCSID 1208);
   
  insert into SHOPIFY.testclob  
  SELECT LINE FROM TABLE(QSYS2.IFS_READ(PATH_NAME => '/home/shopify/orders.txt',
                                   END_OF_LINE => 'CRLF'));
  
 create table SHOPIFY.ttorders  as (
 SELECT t.id, t.order_number, t.confirmation_number, t.confirmed, t.contact_email, t.created_at, t.currency, t.current_subtotal_price,
       t.po_number, t.note,
       t.shipping_name, t.shipping_address1,
       t.shipping_address2, t.city, t.state, t.zip, t.shipping_lines,t.line_items
       from SHOPIFY.testclob,
        JSON_TABLE(  
                    SHOPIFY.testclob.jsondoc,
                   'lax $.orders[*]'       
                   COLUMNS (
                            id           CHAR(15) PATH 'lax $.id',             
                            order_number CHAR(10) PATH 'lax $.order_number',
                            confirmation_number CHAR(25) PATH 'lax $.confirmation_number',
                            confirmed CHAR(5) PATH 'lax $.confirmed',
                            contact_email  CHAR(75) PATH 'lax $.contact_email',
                            created_at CHAR(35) PATH 'lax $.created_at',
                            currency CHAR(5) PATH 'lax $.currency',
                            current_subtotal_price CHAR(15) PATH 'lax $.current_subtotal_price', 
                            po_number     CHAR(15) PATH 'lax $.po_number',
                            note          CHAR(60) PATH 'lax $.note',
                            shipping_name CHAR(30) PATH 'lax $.shipping_address.name',
                            shipping_address1 CHAR(50) PATH 'lax $.shipping_address.address1',
                            shipping_address2 CHAR(50) PATH 'lax $.shipping_address.address2',
                            city         CHAR(25) PATH 'lax $.shipping_address.city',
                            state        CHAR(5) PATH 'lax $.shipping_address.province_code',
                            zip          CHAR(10) PATH 'lax $.shipping_address.zip',
                            shipping_lines  CHAR(5000) FORMAT JSON PATH 'lax $.shipping_lines',
                            line_items  CHAR(5000) FORMAT JSON PATH 'lax $.line_items'
                            )
                   ) AS t) with data;
  
  update SHOPIFY.ttorders set line_items = '{"items":' || trim(line_items) || '}', 
                                     shipping_lines =  '{"lines":' || trim(shipping_lines) || '}';

 create table SHOPIFY.ttorders2  as (
 SELECT  ID, ORDER_NUMBER, CONFIRMATION_NUMBER, CONFIRMED, CONTACT_EMAIL, CREATED_AT, 
              CURRENCY, CURRENT_SUBTOTAL_PRICE,PO_NUMBER,NOTE,
              SHIPPING_NAME, SHIPPING_ADDRESS1,SHIPPING_ADDRESS2,CITY,STATE,ZIP,i.carrier_identifier,i.code,
              t.name,t.sku,t.quantity,t.price,t.currency_code
       from SHOPIFY.ttorders,
       
        JSON_TABLE(  
                   SHOPIFY.ttorders.shipping_lines,
                   'lax $.lines[*]'
                   COLUMNS (carrier_identifier CHAR(50) PATH 'lax $.carrier_identifier',
                                    code CHAR(10) PATH 'lax $.code'
                            )
                    ) AS i,        
                            
        JSON_TABLE(  
                   SHOPIFY.ttorders.line_items,
                   'lax $.items[*]'
                   COLUMNS (price CHAR(15) PATH 'lax $.price',
                                    name CHAR(15) PATH 'lax $.name',
                                    sku    CHAR(15) PATH 'lax $.sku',
                                    quantity CHAR(10) PATH 'lax $.quantity',
                                    currency_code  CHAR(10) PATH 'lax $.price_set.shop_money.currency_code'
                            )
                   ) AS t) with data;
  
  create table shopify.orders as (
    select o.*, p.barcode  from SHOPIFY.ttorders2 o 
    join shopify.products p on (o.sku = p.sku))
    with data;
	
	drop table SHOPIFY.ttorders2;
        
 END   