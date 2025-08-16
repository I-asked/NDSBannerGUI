unit NDSBannerGUIForms;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls, NDSBanner, bufstream, LazFileUtils;

type

  { TNDSBannerForm }

  TNDSBannerForm = class(TForm)
    LoadButton: TButton;
    ImagePreview: TImage;
    ImagePanel: TPanel;
    OpenDialog: TOpenDialog;
    SaveButton: TButton;
    SaveDialog: TSaveDialog;
    Title: TMemo;
    procedure LoadButtonClick(Sender: TObject);
    procedure SaveButtonClick(Sender: TObject);
  private
    InFile: String;
    procedure LoadInputFile(FileName: String);
    procedure SaveHeaderBin(FileName: String);
  end;

var
  NDSBannerForm: TNDSBannerForm;

implementation

{$R *.lfm}

{ TNDSBannerForm }

procedure TNDSBannerForm.LoadInputFile(FileName: String);
begin
  if FileExists(FileName) then
  begin
    try
      ImagePreview.Picture.LoadFromFile(FileName);

      InFile := FileName;

      SaveButton.Enabled := True;
      Title.Lines.Clear;
      Title.Lines.Add(ExtractFileNameOnly(FileName));
    except
      on E: Exception do
        MessageDlg('Load failed', E.Message, mtError, [mbOK], 0);
    end;
  end
end;

procedure TNDSBannerForm.SaveHeaderBin(FileName: String);
var
  Stream: TBufferedFileStream;
  Line: String;
  TitleRaw: UnicodeString;
begin
  Stream := TBufferedFileStream.Create(FileName, fmCreate);
  TitleRaw := '';
  for Line in Title.Lines do
    TitleRaw := TitleRaw + UnicodeString(Line) + sLineBreak;
  TitleRaw := TrimRight(TitleRaw);
  try
    try
      CreateNDSBanner(InFile, Stream, TitleRaw);
    except
      on E: Exception do
        MessageDlg('Processing failed', E.Message, mtError, [mbOK], 0);
    end;
  finally
    Stream.Destroy;
  end;
end;

procedure TNDSBannerForm.LoadButtonClick(Sender: TObject);
begin
  if OpenDialog.Execute then
    LoadInputFile(OpenDialog.FileName);
end;

procedure TNDSBannerForm.SaveButtonClick(Sender: TObject);
begin
  if SaveDialog.Execute then
    SaveHeaderBin(SaveDialog.FileName);
end;

end.

