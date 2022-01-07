unit main;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ComCtrls, StdCtrls, MTProcs;

type

  { TForm1 }

  TForm1 = class(TForm)
    Button1: TButton;
    Edit1: TEdit;
    Edit2: TEdit;
    Label1: TLabel;
    ProgressBar1: TProgressBar;
    procedure Button1Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure DoSomethingParallel(Index: PtrInt; Data: Pointer; Item: TMultiThreadProcItem);
  private
    procedure SetPosition( step: Integer );
  public
  end;

var
  Form1: TForm1;
  perc : Integer;

implementation

{$R *.lfm}

procedure TForm1.DoSomethingParallel(Index: PtrInt; Data: Pointer; Item: TMultiThreadProcItem);
var
  i: Integer;
  sval : String;
  offset : Integer;
begin
  writeln('Thread: ' + IntToStr(Index));
  sval := Form1.Edit1.Text;
  case Index of
  0: begin
       offset := Round((StrToInt(sval) * 1000)/100);
       for i:= 0 to 100 do begin
         SetPosition(i);
         sleep(offset);
       end;
     end;
  1: begin
       offset := Round((StrToInt(sval) * 1000)/10);
       for i:= 0 to 10 do begin
         Edit2.ReadOnly := False;
         //writeln(IntToStr(i));
         Edit2.Text := IntToStr(i);
         Edit2.ReadOnly := True;
         sleep(offset);
       end;
     end;
  end;
end;

{ TForm1 }

procedure TForm1.SetPosition( step: Integer );
begin
  //writeln('Position: ' + IntToStr(step));
  ProgressBar1.position := step;
  Application.ProcessMessages;
end;


procedure TForm1.Button1Click(Sender: TObject);
begin
  ProcThreadPool.DoParallel(@DoSomethingParallel,0,1,nil);
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  ProgressBar1.Min := 0;
  ProgressBar1.Max := 100;
  ProgressBar1.Smooth := True;
  ProgressBar1.Enabled := True;
end;

end.

