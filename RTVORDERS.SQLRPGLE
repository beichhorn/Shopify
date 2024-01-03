**FREE
//--------------------------------------------------------------------
//
// PURPOSE: Retrieve Orders from Shopify store
//
// M A I N T E N A N C E   L O G
// -----------------------------
// BJE 01/02/2023: Created
//
//-------------------------------------------------------------------
Ctl-Opt Option(*SrcStmt);

// Files
Dcl-F StoreData;
Dcl-F Fulapi  Usage(*OUTPUT);

// Data Structure
Dcl-DS  Orders_DATA    Extname('ORDERS') End-DS;

Dcl-Pr  Call_QCMDEXC    Extpgm('QCMDEXC');
  Command      Char(150);
  CmdLength    Packed(15:5);
End-Pr;

Dcl-Pr  Rtv_UTCOFFSET  Extpgm('UTCOFFSETC');
  UTCOffset   Char(5);
End-Pr;

// Declare Variables
Dcl-S path        Char(50);
Dcl-S fd          Int(10);
Dcl-S Line        Char(300);
Dcl-S Command     Char(150);
Dcl-S CmdLength   Packed(15:5) Inz(150);
Dcl-S ProcDate    Char(26)  Dtaara;
Dcl-S Year        Packed(4:0);
Dcl-S Month       Packed(2:0);
Dcl-S Day         Packed(2:0);
Dcl-S Hour        Packed(2:0);
Dcl-S Minutes     Packed(2:0);
Dcl-S Seconds     Packed(2:0);
Dcl-S DateTime    Timestamp;
Dcl-S StartTime   Char(25);
Dcl-S EndTime     Char(25);
Dcl-S UTCOffset   Char(5);
Dcl-S UTCOffsetEdited  Char(6);

// Declare Constants
Dcl-C ##PATH_NAME   '/home/shopify/config.txt';
Dcl-C CRLF          x'0d25';
Dcl-C cSqt          x'7d';
Dcl-C ##YES         '1';

// ------------------------------------------------------------------------------------------
// Mainline Routine
// ------------------------------------------------------------------------------------------

  // Retrieve the UTC Offset (in Hours)
  Rtv_UTCOFFSET(UTCOffset);
  UTCOffsetEdited = %subst(UTCOffset:1:3) + ':' + %subst(UTCOffset:4:2);

  // Get Starting Date/Time
  In *LOCK ProcDate;
  DateTime = %timestamp(ProcDate) + %seconds(1);
  Month = %subdt(DateTime:*M);
  Day   = %subdt(DateTime:*D);
  Year  = %subdt(DateTime:*Y);
  Hour  = %subdt(DateTime:*H);
  Minutes = %subdt(DateTime:*MN);
  Seconds = %subdt(DateTime:*S);

  StartTime = %char(Year) + '-' + %editc(Month:'X') + '-' + %editc(Day:'X') + 'T' +
             %editc(Hour:'X') + ':' + %editc(Minutes:'X') + ':' + %editc(Seconds:'X') +
             UTCOffsetEdited;

  // Calculate Ending Date/Time (10 minutes before NOW)
  DateTime = %timestamp - %minutes(10);
  Month = %subdt(DateTime:*M);
  Day   = %subdt(DateTime:*D);
  Year  = %subdt(DateTime:*Y);
  Hour  = %subdt(DateTime:*H);
  Minutes = %subdt(DateTime:*MN);
  Seconds = %subdt(DateTime:*S);

  EndTime = %char(Year) + '-' + %editc(Month:'X') + '-' + %editc(Day:'X') + 'T' +
             %editc(Hour:'X') + ':' + %editc(Minutes:'X') + ':' + %editc(Seconds:'X') +
             UTCOffsetEdited;

  // Loop through Physical File to get Get Store Name, Token and Customer Code
  Dou %eof(StoreData);
    Read StoreData;

    If not %eof(StoreData);

    exec sql CALL QSYS2.IFS_WRITE_UTF8(PATH_NAME =>:##PATH_NAME,
                       LINE => '',
                       OVERWRITE => 'REPLACE',
                       END_OF_LINE => 'NONE');

      line = '--url "https://' + %trim(Store) + '.myshopify.com/admin/api/2023-10/orders.json?status=any' +
             '&processed_at_min=' + StartTime + '&processed_at_max=' + EndTime + '"';
      exec sql CALL QSYS2.IFS_WRITE_UTF8(PATH_NAME => :##PATH_NAME, LINE => :line);

      line = '--insecure ';
      exec sql CALL QSYS2.IFS_WRITE_UTF8(PATH_NAME => :##PATH_NAME, LINE => :line);

      line = 'header = "Content-Type: application/json"';
      exec sql CALL QSYS2.IFS_WRITE_UTF8(PATH_NAME => :##PATH_NAME, LINE => :line);

      line = 'header = "X-Shopify-Access-Token: ' + %trim(Token) + '"';
      exec sql CALL QSYS2.IFS_WRITE_UTF8(PATH_NAME => :##PATH_NAME, LINE => :line);

      line = '-o "/home/shopify/orders.txt"';
      exec sql CALL QSYS2.IFS_WRITE_UTF8(PATH_NAME => :##PATH_NAME, LINE => :line);

      //  Delete Temporary Tables
      Monitor;
        Command = 'DLTF SHOPIFY/TESTCLOB';
        Call_QCMDEXC(Command:CmdLength);
      On-Error;
      Endmon;

      Monitor;
        Command = 'DLTF SHOPIFY/TTORDERS';
        Call_QCMDEXC(Command:CmdLength);
      On-Error;
      Endmon;

      Monitor;
        Command = 'DLTF SHOPIFY/TTORDERS2';
        Call_QCMDEXC(Command:CmdLength);
      On-Error;
      Endmon;

      // Delete Orders File before recreating
      Monitor;
        Command = 'DLTF SHOPIFY/ORDERS';
        Call_QCMDEXC(Command:CmdLength);
      On-Error;
      Endmon;

      // Run CURL command to get data from API
      Command = 'QSH CMD(' + cSqt + 'curl -K /home/shopify/config.txt'  + cSqt + ')';
      Call_QCMDEXC(Command:CmdLength);

      // Run SQL stored procedure to recreate a revised ORDERS table
      Command = 'RUNSQL SQL(' + cSqt + 'call shopify.NEW_ORDERS' + cSqt + ') COMMIT(*NONE)';
      Call_QCMDEXC(Command:CmdLength);

      // Populate FILESA/FULAPI from SHOPIFY/ORDERS
      exec sql declare C1 cursor for select
        ID,
        ORDER_NUMBER,
        CONFIRMATION_NUMBER,
        CONFIRMED,
        COALESCE(CONTACT_EMAIL,' '),
        CREATED_AT,
        CURRENCY,
        CURRENT_SUBTOTAL_PRICE,
        COALESCE(PO_NUMBER, ' '),
        COALESCE(NOTE, ' '),
        COALESCE(SHIPPING_NAME, ' '),
        SHIPPING_ADDRESS1,
        COALESCE(SHIPPING_ADDRESS2, ' '),
        CITY,
        STATE,
        ZIP,
        CARRIER_IDENTIFIER,
        CODE,
        NAME,
        SKU,
        QUANTITY,
        PRICE,
        CURRENCY_CODE,
        BARCODE
        from orders
          order by order_number, sku;

      exec sql open C1;

      Dou sqlstate > '02';
        exec sql fetch next from C1 into
          :ID,
          :ORDER00001,
          :CONFI00001,
          :CONFIRMED,
          :CONTA00001,
          :CREATED_AT,
          :CURRENCY,
          :CURRE00001,
          :PO_NUMBER,
          :NOTE,
          :SHIPP00001,
          :SHIPP00002,
          :SHIPP00003,
          :CITY,
          :STATE,
          :ZIP,
          :CARRI00001,
          :CODE,
          :NAME,
          :SKU,
          :QUANTITY,
          :PRICE,
          :CURRE00002,
          :BARCODE;

        If sqlstate < '02';
          // Populate FULAPI fields
          FASTOR = STORE;
          FAPINV = ORDER00001;
          FACFM# = CONFI00001;
          FACONF = CONFIRMED;
          FAEML1 = CONTA00001;
          FASUBM = CREATED_AT;
          FACURT = CURRENCY;
          FATOTL = %dec(CURRE00001:9:2);
          FACLN1 = SHIPP00001;
          FACLN2 = SHIPP00002;
          FACLN3 = CITY;
          FACLN4 = STATE;
          FACLN5 = *blanks;
          FACLN6 = *blanks;
          FACZIP = ZIP;
          FACARR = CARRI00001;
          FASHCD = CODE;
          FATITL = NAME;
          FASKU = SKU;
          FAQTYO = %int(QUANTITY);
          FAPRIC = %dec(PRICE:6:2);
          FACURD = CURRE00002;
          FASTK# = BARCODE;
          FAPPO# = PO_NUMBER;
          FANOTE = NOTE;
          FAODAT = %int(%char(%date:*YMD0));
          FAOTIM = %int(%char(%time:*HMS0));
          FAPUBL = CUSTCODE;
          FAORID = ID;
          Write FULAPIR;
        Endif;

      Enddo;

      exec sql close C1;

    Endif;

  Enddo;

// Update Last Processed Date/Time
ProcDate = %char(DateTime);
Out ProcDate;

*INLR = ##YES;
Return;

