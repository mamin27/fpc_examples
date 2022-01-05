unit unt_main;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, EditBtn,
  StdCtrls, DBGrids, ExtCtrls, DBExtCtrls, DBCtrls, DB, BufDataset, SQLite3Conn,
  SQLDB, SQLDBLib, dbf, memds, Math, unt_plus, DateUtils, Grids;

type

  { TAUThread }

  TAUThread = class(TThread)
    protected
      _ID: Int64;
      _FileToScan: string;
      _FileName: string;
      _CurrentHash: string;
      _CurrentStart: qword;
      _CurrentEnd: qword;
      _CurrentSize: qword;
      _BlockSize: qword;
      _FileSize: qword;
      _FileParts: qword;
      _ScannedSize: qword;
      _ScannedParts: qword;
      procedure Execute; override;
    private
      procedure SendCurrentStatus;
      procedure SendStartStatus;
      procedure SendEndStatus;
    public
      constructor Create(const CreateSuspended, AutoFree: boolean; const FileToScan: string; BlockSize: QWord; const ID: Int64=-1);
    published
  end;

  { TForm1 }

  TForm1 = class(TForm)
    BufDataset1: TBufDataset;
    BufDataset1filepath: TStringField;
    BufDataset1pathseq: TStringField;
    BufDataset1start: TStringField;
    BufDataset1end: TStringField;
    BufDataset1size: TStringField;
    Button1: TButton;
    Button2: TButton;
    DataSource: TDataSource;
    DBGrid1: TDBGrid;
    dsStats: TDataSource;
    DirectoryEdit1: TDirectoryEdit;
    Edit1: TEdit;
    Label1: TLabel;
    Label2: TLabel;
    SQLDBLibraryLoader1: TSQLDBLibraryLoader;
    SQLite3Connection: TSQLite3Connection;
    SQLQuery: TSQLQuery;
    SQLTransaction: TSQLTransaction;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure DirectoryEdit1Change(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure SetRW ( freadonly: boolean);
  protected
    _Completed: array of Boolean;
    _TotalSize: qword;
    _TotalParts: qword;
    _TotalScannedSize: qword;
    _TotalScannedParts: qword;
    _DedupAmount: qword;
    _RepeatedParts: qword;
    _StartMoment: TDateTime;
    _EndMoment: TDateTime;
  private
    procedure ReceiveStartStatus(const FileSize, FileParts: qword);
    procedure ReceiveCurrentStatus(const PartHash, FilePath: string; const PartSeq, PartStart, PartEnd, PartSize: QWord);
    procedure ReceiveEndStatus(const ID: Int64);
  public
    { public declarations }
  end;

  TAccessDBGrid = class(TDBGrid);

var
  Form1: TForm1;
  Robots: array of TAUThread;

implementation

{$R *.lfm}

{ TForm1 }

procedure TForm1.SetRW (freadonly: boolean);
begin
  BufDataset1filepath.ReadOnly:= freadonly;
  BufDataset1pathseq.ReadOnly:= freadonly;
  BufDataset1start.ReadOnly:= freadonly;
  BufDataset1end.ReadOnly:= freadonly;
  BufDataset1size.ReadOnly:= freadonly;
end;

procedure TForm1.Button1Click(Sender: TObject);
var
  NewFile: Boolean;
  FoundFiles: TStringList;
  x: longint;
begin
  _StartMoment:=now;
  _EndMoment:=_StartMoment;
  Button1.Enabled:=False;
  DirectoryEdit1.Enabled:=False;
  Edit1.Enabled:=False;
  Label2.Caption:='Starting... please wait!';
  Application.ProcessMessages;
  SetRW (False);

  SQLite3Connection.Close; // Ensure the connection is closed when we start

  //SQLite3Connection.DatabaseName;

  try
    SQLite3Connection.Open;
    SQLTransaction.Active := true;

    SQLite3Connection.ExecuteDirect('DROP TABLE IF EXISTS scan;');
    SQLite3Connection.ExecuteDirect('CREATE TABLE scan(id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT UNIQUE, parthash VARCHAR(255), filepath VARCHAR(255), partseq INTEGER, partstart INTEGER, partend INTEGER, partsize INTEGER);');
    SQLTransaction.Commit;

    ShowMessage('Table recreated.');
  except
    ShowMessage('Unable to recreate Table');
  end;

  FoundFiles:=FindAllFiles(DirectoryEdit1.Text,'*',True,faAnyFile);
  SetLength(Robots,FoundFiles.Count);
  writeln(DirectoryEdit1.Text + ' : ' + IntToStr(FoundFiles.Count));
  SetLength(_Completed,FoundFiles.Count);
  _TotalSize:=0;
  _TotalParts:=0;
  _TotalScannedSize:=0;
  _TotalScannedParts:=0;
  _RepeatedParts:=0;
  Label2.Caption:='Scanning... to see more information, click on "Refresh"!';
  Application.ProcessMessages;
  for x:=Low(Robots) to High(Robots) do begin
    _Completed[x]:=False;
    //writeln('Set False: ' + IntToStr(x) + ' : ' + FoundFiles.Strings[x]);
    Robots[x]:=TAUThread.Create(True,True,FoundFiles.Strings[x],StrToInt(Edit1.Text),x);
    Robots[x].Execute;
  end;

  SQLite3Connection.Close;
  SQLite3Connection.Open;
  SQLQuery.SQL.Clear;

  SQLQuery.SQL.Text := 'SELECT filepath AS Path,partseq AS Sequence,partstart AS start,partend AS end,partsize AS size FROM scan GROUP BY parthash HAVING COUNT(*)>1 ORDER BY id ASC;';
  DataSource.DataSet := BufDataset1;
  DBGrid1.DataSource := DataSource;

  SQLQuery.Open();
  while not SQLQuery.EOF do
    begin
      BufDataset1.AppendRecord([SQLQuery.Fields[0].AsString,SQLQuery.Fields[1].AsString,SQLQuery.Fields[2].AsString,SQLQuery.Fields[3].AsString,SQLQuery.Fields[4].AsString]);
      SQLQuery.next;
    end;

  //BufDataset1.Active := false;
  SetRW (True);
  SQLQuery.Close;
  SQLite3Connection.Close;
  FoundFiles.Free;
  Button2.Enabled:=True;
  DirectoryEdit1.Enabled:=True;
  Label2.Caption:='Scaned now!';
end;

procedure TForm1.Button2Click(Sender: TObject);
var
  pgrs: string;
  proportion: string;
  alldone: boolean=True;
  time: qword;
  x: longint;
begin
  if Button2.Enabled and not(Button1.Enabled)
    then begin
      DBGrid1.Clear;
      _DedupAmount:=0;
      _RepeatedParts:=0;
      SQLite3Connection.Open;
      SQLQuery.Transaction := SQLTransaction;
      DataSource.DataSet := SQLQuery;

      SQLQuery.SQL.Text := 'SELECT partsize AS upartsizes FROM scan GROUP BY parthash;';
      SQLQuery.Open();

      SQLQuery.First;
      while not SQLQuery.EOF do begin
        _DedupAmount:=_DedupAmount+SQLQuery.FieldByName('upartsizes').AsLongint;
        _RepeatedParts:=_RepeatedParts+1;
        SQLQuery.Next;
      end;
      _DedupAmount:=_TotalScannedSize-_DedupAmount;
      SQLite3Connection.Close;
      pgrs:=FloatToStr(Min(100,Max((_TotalScannedSize*100)/_TotalSize,(_TotalScannedParts*100)/_TotalParts)));
      if Length(pgrs)>5
        then pgrs:=pgrs[Low(pgrs)..Low(pgrs)+4];
      if _StartMoment=_EndMoment
        then time:=MinutesBetween(_StartMoment,Now)
        else time:=MinutesBetween(_StartMoment,_EndMoment);
      proportion:=FloatToStr((((_DedupAmount div 1024) div 1024)*100)/Max(1,((_TotalScannedSize div 1024) div 1024)));
      if Length(proportion)>5
        then proportion:=proportion[Low(proportion)..Low(proportion)+4];
      Label2.Caption:='Elapsed time: '+IntToStr(time div 60)+'h and '+IntToStr(time mod 60)+' min; Size (Scanned/Total): '+IntToStr((_TotalScannedSize div 1024) div 1024)+' MiB/'+IntToStr((_TotalSize div 1024) div 1024)+' MiB; Parts (Scanned/Total): '+IntToStr(_TotalScannedParts)+'/'+IntToStr(_TotalParts)+'; Dedup ratio (Parts/Amount/Proportion): '+IntToStr(_TotalScannedParts-_RepeatedParts)+'/~'+IntToStr((_DedupAmount div 1024) div 1024)+' MiB/~'+proportion+'%; Progress: '+pgrs+'%.';
      for x:=Low(_Completed) to High(_Completed) do if _Completed[x]=False
        then alldone:=False;
      if alldone
        then begin
          if _StartMoment=_EndMoment
            then _EndMoment:=now;
          if pgrs='100'
            then Button2.Enabled:=False;
        end;
    end;
end;

procedure TForm1.DirectoryEdit1Change(Sender: TObject);
begin
  Button1.Enabled := True;
  BufDataset1.Active := false;
  BufDataset1.Active := True;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  BufDataset1.CreateDataset;
  BufDataset1.Active := true;
end;

procedure TForm1.ReceiveStartStatus(const FileSize, FileParts: qword);
begin
  _TotalSize:=_TotalSize+FileSize;
  _TotalParts:=_TotalParts+FileParts;
end;

procedure TForm1.ReceiveCurrentStatus(const PartHash,FilePath: string; const PartSeq, PartStart, PartEnd, PartSize: QWord);
begin
  SQLite3Connection.Open;
  SQLQuery.Transaction := SQLTransaction;
  DataSource.DataSet := SQLQuery;

  try
    SQLQuery.SQL.Text := 'INSERT INTO scan VALUES(null,"'+PartHash+'","'+FilePath+'",'+IntToStr(PartSeq)+','+IntToStr(PartStart)+','+IntToStr(PartEnd)+','+IntToStr(PartSize)+');';
    SQLQuery.ExecSQL();
    SQLTransaction.Commit()

  except
    ShowMessage('Unable to INSERT');
  end;

  SQLite3Connection.Close;

  _TotalScannedSize:=_TotalScannedSize+PartSize;
  _TotalScannedParts:=_TotalScannedParts+1;
end;

procedure TForm1.ReceiveEndStatus(const ID: Int64);
begin
  _Completed[ID]:=True;
end;

{ TAUThread }

procedure TAUThread.Execute;
var
  FS: TFileStream;
  buf: TMemoryStream;
begin
  FS:=TFileStream.Create(_FileToScan,fmOpenRead);
  _FileSize:=FS.Size;
  //writeln('Size: ' + IntToStr(_FileSize));
  if (_FileSize mod _BlockSize>0)
    then _FileParts:=(_FileSize div _BlockSize)+1
    else _FileParts:=(_FileSize div _BlockSize);
  Synchronize(@SendStartStatus);
  while not(FS.Position>=FS.Size-1) do begin
    buf:=TMemoryStream.Create;
    if _BlockSize < FS.Size-1-FS.Position then buf.CopyFrom(FS,_BLockSize)
      else buf.CopyFrom(FS,FS.Size-1-FS.Position);
    _CurrentHash:='';
    _CurrentStart:=FS.Position-buf.Size;
    _CurrentEnd:=FS.Position-1;
    _CurrentSize:=buf.Size;
    CalcStreamHash(buf,_CurrentHash);
    buf.Free;
    _ScannedSize:=FS.Position+1;
    _ScannedParts+=1;
    Synchronize(@SendCurrentStatus);
  end;
  FS.Free;
  Synchronize(@SendEndStatus);
end;

procedure TAUThread.SendCurrentStatus;
begin
  Form1.ReceiveCurrentStatus(_CurrentHash,_FileToScan,_ScannedParts-1,_CurrentStart,_CurrentEnd,_CurrentSize);
end;

procedure TAUThread.SendStartStatus;
begin
  Form1.ReceiveStartStatus(_FileSize,_FileParts);
end;

procedure TAUThread.SendEndStatus;
begin
  Form1.ReceiveEndStatus(_ID);
end;

constructor TAUThread.Create(const CreateSuspended, AutoFree: boolean; const FileToScan: string; BlockSize: QWord; const ID: Int64=-1);
var
  x,p: word;
begin
  _ID:=ID;
  _FileToScan:=FileToScan;
  _BlockSize:=Max(20,BlockSize);
  _FileSize:=0;
  _FileParts:=0;
  _ScannedSize:=0;
  _ScannedParts:=0;
  _CurrentHash:='';
  _CurrentStart:=0;
  _CurrentEnd:=0;
  _CurrentSize:=0;
  for x:=Low(_FileToScan) to High(_FileToScan) do
    if _FileToScan[x]=PathDelim
        then p:=x+1;
  _FileName:=_FileToScan[p..High(_FileToScan)];
  FreeOnTerminate:=AutoFree;
  inherited Create(CreateSuspended);
end;

end.

