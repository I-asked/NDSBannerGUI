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
    procedure UpdatePreview;
    procedure SaveHeaderBin(FileName: String);
  end;

var
  NDSBannerForm: TNDSBannerForm;

implementation

{$R *.lfm}

{ TNDSBannerForm }

procedure TNDSBannerForm.UpdatePreview;
begin
  if FileExists(InFile) then
  begin
    ImagePreview.Picture.LoadFromFile(InFile);
    SaveButton.Enabled := True;
    Title.Lines.Clear;
    Title.Lines.Add(ExtractFileNameOnly(InFile));
  end
  else
    SaveButton.Enabled := False;
end;

procedure TNDSBannerForm.SaveHeaderBin(FileName: String);
var
  Stream: TBufferedFileStream;
  Line: String;
  TitleRaw: UnicodeString;
begin
  Stream := TBufferedFileStream.Create(FileName, fmOpenWrite);
  TitleRaw := '';
  for Line in Title.Lines do
    TitleRaw := TitleRaw + UnicodeString(Line) + sLineBreak;
  TitleRaw := TrimRight(TitleRaw);
  try
    CreateNDSBanner(InFile, Stream, TitleRaw);
  finally
    Stream.Destroy;
  end;
end;

procedure TNDSBannerForm.LoadButtonClick(Sender: TObject);
begin
  if OpenDialog.Execute then
  begin
    InFile := OpenDialog.FileName;
    UpdatePreview;
  end;
end;

procedure TNDSBannerForm.SaveButtonClick(Sender: TObject);
begin
  if SaveDialog.Execute then
    SaveHeaderBin(SaveDialog.FileName);
end;

end.

