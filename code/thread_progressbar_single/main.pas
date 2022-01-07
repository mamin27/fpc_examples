unit main;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ComCtrls, StdCtrls;

type

  { TAUThread }

  TAUThread = class(TThread)
    protected
      _ID: Int64;
      _percentage:integer;
      procedure Execute; override;
    private
      procedure SendPositionStatus;
      procedure SendEndStatus;
    public
      constructor Create(const CreateSuspended, AutoFree: boolean; ID: Int64);
    published
  end;

  { TForm1 }

  TForm1 = class(TForm)
    Button1: TButton;
    Edit1: TEdit;
    Edit2: TEdit;
    ProgressBar1: TProgressBar;
    procedure Button1Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  protected
    _Completed: array [0..1] of Boolean;
  private
    function ReceivePositionStatus(): Integer;
    procedure SetPosition( step: Integer );
    procedure ReceiveEndStatus( ID: Int64);
  public

  end;

var
  Form1: TForm1;
  Robots: array [0..1] of TAUThread;
  Robot: TAUThread;
  perc : Integer;

implementation

{$R *.lfm}

{ TForm1 }

function TForm1.ReceivePositionStatus(): Integer;
begin
  ReceivePositionStatus := ProgressBar1.position;
end;

procedure TForm1.SetPosition( step: Integer );
begin
  //writeln('Position: ' + IntToStr(step));
  ProgressBar1.position := step;
  Application.ProcessMessages;
end;

procedure TForm1.ReceiveEndStatus(ID:Int64);
begin
  //writeln('Thread done');
  _Completed[ID]:=True;
end;

procedure TForm1.Button1Click(Sender: TObject);
begin
  //writeln('Thread started');
  _Completed[0]:=False;
  Robots[0] := TAUThread.Create(True,True,0);
  Robots[1] := TAUThread.Create(True,True,1);
  Robots[0].Execute;
  Robots[1].Execute;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  ProgressBar1.Min := 0;
  ProgressBar1.Max := 100;
  ProgressBar1.Smooth := True;
  ProgressBar1.Enabled := True;
end;

{ TAUThread }

procedure TAUThread.Execute;
var
  //buf: TMemoryStream;
  i : Integer;
  sval : String;
  offset : Integer;
begin
  Form1.Edit2.Text := '';
  sval := Form1.Edit1.Text;
  case _ID of
  0: begin
       offset := Round((StrToInt(sval) * 1000)/100);
       for i:= 0 to 100 do begin
         Form1.SetPosition(i);
         sleep(offset);
         Synchronize(@SendPositionStatus);
       end;
     end;
  1: begin
       offset := Round((StrToInt(sval) * 1000)/10);
       for i:= 0 to 10 do begin
         Form1.Edit2.ReadOnly := False;
         writeln(IntToStr(i));
         Form1.Edit2.Text := IntToStr(i);
         Form1.Edit2.ReadOnly := True;
         sleep(offset);
       end;
     end;
  end;
  Form1.ReceiveEndStatus(_ID);
  Synchronize(@SendEndStatus);
end;

procedure TAUThread.SendPositionStatus;
begin
  _percentage := Form1.ReceivePositionStatus();
end;

procedure TAUThread.SendEndStatus;
begin
  inherited Destroy;
end;

constructor TAUThread.Create(const CreateSuspended, AutoFree: boolean; ID: Int64);
begin
  _ID:=ID;
  _percentage:=0;
  FreeOnTerminate:=AutoFree;
  inherited Create(CreateSuspended);
end;

end.

