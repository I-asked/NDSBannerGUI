unit NDSBanner;

{$mode ObjFPC}{$H+}

interface

uses
  ctypes, Math, Classes, SysUtils, magick_wand, ImageMagick;

procedure CreateNDSBanner(InFile: String; OutStr: TStream; Text: UnicodeString);

implementation

function MagickGetImageTicksPerSecond(wand: PMagickWand): culong; cdecl; external WandExport;

procedure ThrowWandException(Wand: PMagickWand);
var
  Message: String;
  Description: PChar;
  Severity: ExceptionType;
begin
  Description := MagickGetException(Wand, @Severity);
  Message := Description;
  Description := MagickRelinquishMemory(Description);
  raise Exception.Create(Message);
end;

type
  TCRC16 = Word;

function CRC16(Inp: PByte; Size: SizeUInt; Initial: Word = $FFFF): TCRC16; inline;
var
  I, J, Tmp: Integer;
const
  Val: Array[0..7] of Word = (
    $C0C1, $C181, $C301, $C601,
    $CC01, $D801, $F001, $A001
  );
begin
  Tmp := Initial;

  for I := 0 to Size - 1 do
  begin
    Tmp := Tmp xor Word(Inp[I]);
    for J := 0 to 7 do
      if (Tmp and 1) <> 0 then
        Tmp := (Tmp shr 1) xor (Val[J] shl (7 - J))
      else
        Tmp := Tmp shr 1;
  end;

  CRC16 := TCRC16(Tmp);
end;

{ Implementation based on GBATEK }

type
  {$PUSH}{$A1}
  TNDSBanner = record
    Version: Word;
    CRC: Array[0..14] of TCRC16;

    StaticIndices: Array[0..3, 0..3, 0..7, 0..3] of Byte;
    StaticPalette: Array[0..15] of Word;

    Title: Array[0..15, 0..127] of Word;

    AnimIndices: Array[0..7, 0..3, 0..3, 0..7, 0..3] of Byte;
    AnimPalette: Array[0..7, 0..15] of Word;
    AnimSeq: Array[0..63] of Word;
  end;
  {$POP}

{$PUSH}{$WARN 5027 off : Local variable "$1" is assigned but never used}
procedure CreateNDSBanner(InFile: String; OutStr: TStream; Text: UnicodeString);
var
  Status: MagickBooleanType;
  Wand: PMagickWand;
  Size: MagickSizeType;
  Buf: PByte;
  X, Y, I, J, Count, PalPtr: LongInt;
  Banner: TNDSBanner;
  TmpVal16: Word;
  TmpVal8: Byte;
  UniChar: WChar;
  HasTrans: Boolean;
  Delay, TPS: LongWord;
  TmpPByte: PByte;
  TmpDither: Integer = 0;
  TmpMErr: Integer = 0;

  function InsPal(RGBA: PByte): Byte;
  var
    K: LongInt;
    R, G, B: Byte;
    TmpColor16: Word;
  begin
    Result := 0;
    if RGBA[3] < 127 then
      Exit; // palette entry 0 is always 0% opacity

    R := RGBA[0] shr 3;
    G := RGBA[1] shr 3;
    B := RGBA[2] shr 3;


    TmpColor16 := NtoLE((R and 31) or ((G and 31) shl 5) or ((B and 31) shl 10));

    if PalPtr > 0 then
      for K := 1 to PalPtr do
        if Banner.AnimPalette[I, K] = TmpColor16 then
        begin
          Result := K;
          Exit;
        end;

    Inc(PalPtr);
    if PalPtr > 15 then
      raise Exception.Create('Palette size exceeds 16 colors');

    Result := PalPtr;

    Banner.AnimPalette[I, PalPtr] := TmpColor16;
    if I = 0 then
      Banner.StaticPalette[PalPtr] := TmpColor16;
  end;

begin
  Initialize(Banner);
  FillChar(Banner, SizeOf(Banner), $00);

  with Banner do
  begin
    Version := $0003;

    StaticPalette[0] := $7FFF;

    J := 0;
    for UniChar in Text do
    begin
      for I := 0 to 7 do
        Title[I, J] := NtoLE(Word(UniChar));
      Inc(J);
    end;
  end;

  MagickWandGenesis;

  Wand := NewMagickWand;

  try
    Status := MagickReadImage(Wand, PAnsiChar(InFile));
    if Status = MagickFalse then ThrowWandException(Wand);

    Count := MagickGetNumberImages(Wand);
    MagickResetIterator(Wand);

    I := 0;
    while MagickNextImage(Wand) <> MagickFalse do
    begin
      PalPtr := 0;
      if I > 7 then
        raise Exception.Create('Frame > 7');

      TPS := MagickGetImageTicksPerSecond(Wand);
      Delay := Round((Real(MagickGetImageDelay(Wand)) / TPS) * 60.0);

      MagickSetImageFormat(Wand, 'rgba');
      MagickSetImageDepth(Wand, 8);
      MagickResizeImage(Wand, 32, 32, BoxFilter, 0);

      Buf := MagickGetImageBlob(Wand, @Size);
      for J := 0 to Size div 4 do
        if Buf[J * 4 + 3] < 127 then
        begin
          HasTrans := True;
          Break;
        end;
      Buf := MagickRelinquishMemory(Buf);

      MagickQuantizeImage(Wand, 15 + LongInt(HasTrans), RGBColorspace, 0, TmpDither, TmpMErr);

      Buf := MagickGetImageBlob(Wand, @Size);
      with Banner do
      begin
        if I = 1 then Version := $0103;

        AnimPalette[I, 0] := $7FFF;

        if Delay > $FF then
          AnimSeq[(I + 1) mod 8] := $FF
        else if Delay = 0 then
          AnimSeq[(I + 1) mod 8] := 1
        else
          AnimSeq[(I + 1) mod 8] := Delay;

        for Y := 0 to 31 do
          for X := 0 to 15 do
          begin
            TmpVal8 := InsPal(@Buf[(Y * 32 * 4) + (X * 4 * 2) + 0]) or (InsPal(@Buf[(Y * 32 * 4) + (X * 4 * 2) + 4]) shl 4);

            AnimIndices[I, Y div 8, X div 4, Y mod 8, X mod 4] := TmpVal8;
            if I = 0 then StaticIndices[Y div 8, X div 4, Y mod 8, X mod 4] := TmpVal8;
          end;
      end;
      Buf := MagickRelinquishMemory(Buf);

      Delay := 0;
      for J := 1 to Ceil(Count / 8) - 1 do
      begin
        MagickNextImage(Wand);

        TPS := MagickGetImageTicksPerSecond(Wand);
        Delay := Round((Real(MagickGetImageDelay(Wand)) / TPS) * 60.0);

        with Banner do
          if (AnimSeq[(I + 1) mod 8] + Delay) > $FF then
            AnimSeq[(I + 1) mod 8] := $FF
          else
            Inc(AnimSeq[(I + 1) mod 8], Delay);
      end;

      Inc(I);
    end;

  finally
    wand := DestroyMagickWand(Wand);
    MagickWandTerminus;
  end;

  Count := I;

  with Banner do
  begin
    if Version >= $0103 then
      for I := Low(AnimSeq) to Count - 1 do
        AnimSeq[I] := NtoLE(AnimSeq[I] or (I shl 8) or (I shl 11));

    CRC[0] := CRC16(PByte(@Banner) + $20, $820);
    if Version >= 2 then CRC[1] := CRC16(PByte(@Banner) + $20, $920);
    if Version >= 3 then CRC[2] := CRC16(PByte(@Banner) + $20, $A20);
    if Version >= $0103 then CRC[3] := CRC16(PByte(@Banner) + $1240, $1180);

    OutStr.WriteWord(NtoLE(Version));
    for TmpVal16 in CRC do
      OutStr.WriteWord(NtoLE(TmpVal16));

    { should use TStream.WriteData when it's available... }
    TmpPByte := PByte(@Banner) + $20;
    if Version >= $0103 then
      for J := 0 to SizeOf(Banner) - $20 - 1 do
        OutStr.WriteByte(TmpPByte[J])
    else
      for J := 0 to $1220 - 1 do
        OutStr.WriteByte(TmpPByte[J])
  end;
end;
{$POP}

end.

