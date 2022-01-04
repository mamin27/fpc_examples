unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, BufDataset, db, Forms, Controls, Graphics, Dialogs,
  DBGrids, StdCtrls, Menus;

type

  { TForm1 }

  TForm1 = class(TForm)
    BufDataset1: TBufDataset;
    BufDataset1name: TStringField;
    BufDataset1status: TStringField;
    ComboBox1: TComboBox;
    DataSource1: TDataSource;
    DBGrid1: TDBGrid;
    procedure BufDataset1FilterRecord(DataSet: TDataSet; var Accept: Boolean);
    procedure ComboBox1CloseUp(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
  public

  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

{ TForm1 }

procedure TForm1.FormShow(Sender: TObject);
begin
  BufDataset1.AppendRecord(['Married','John']);
  BufDataset1.AppendRecord(['Married','Bill']);
  BufDataset1.AppendRecord(['Single','Jane']);
  BufDataset1.AppendRecord(['Married','Marianne']);
  BufDataset1.AppendRecord(['Single','Peter']);
  combobox1.Items.CommaText := '<none>,Married,Single';
  combobox1.ItemIndex := 0;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  BufDataset1.CreateDataset;
  BufDataset1.Active := true;
end;

procedure TForm1.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  BufDataset1.Active := false;
end;

procedure TForm1.BufDataset1FilterRecord(DataSet: TDataSet; var Accept: Boolean);
begin
  Accept := combobox1.Text = dataset.FieldByName('status').AsString;
end;

procedure TForm1.ComboBox1CloseUp(Sender: TObject);
begin
  try
    bufdataset1.DisableControls;
    bufdataset1.Filtered := false;
    if combobox1.Text <> '<none>' then
      bufdataset1.Filtered := true
  finally
    bufdataset1.EnableControls
  end;
end;

end.

