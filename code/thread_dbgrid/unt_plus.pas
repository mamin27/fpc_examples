unit unt_plus;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, ZStream, Base64,
  DCPcrypt2, DCPmd4, DCPmd5, DCPripemd128, DCPripemd160, DCPtiger, DCPhaval, DCPsha256, DCPsha512, DCPsha1, DCPdes, DCPice, DCPidea, DCPtea,
  DCPcast128, DCPmisty1, DCPrijndael, DCPserpent, DCPtwofish, DCPcast256, DCPblowfish, DCPrc2, DCPmars, DCPrc4, DCPrc5, DCPrc6;
type

  THash = (md4_128=%1,md5_128,rmd_128,rmd_160,sha_160,tiger_192,haval_256,sha_256,sha_384,sha_512);
  TCiph = (des_64=%1,ice_64,thinice_64,ice2_128,idea_128,tea_128,cast_128,misty_128,des3_192,rijndael_256,serpent_256,twofish_256,cast_256,blowfish_448,rc2_1024,mars_1248,rc4_2048,rc5_2048,rc6_2048);

function CalcStreamHash(var Input: TMemoryStream; var Output: string; const Algorithm: THash=rmd_160): boolean;

implementation

function CalcStreamHash(var Input: TMemoryStream; var Output: string; const Algorithm: THash=rmd_160): boolean;
var
  HashClass: class of TDCP_hash;
  Digest: array[$01..$40] of byte;
  Hash: TDCP_hash;
  x: byte=$00;
begin
  result:=False;
  if Assigned(Input)
    then begin
      Output:='';
      for x:=Low(Digest) to High(Digest) do
        Digest[x]:=$00; x:=$00;
      case Algorithm of
        md4_128: HashClass:=TDCP_md4;
        md5_128: HashClass:=TDCP_md5;
        rmd_128: HashClass:=TDCP_ripemd128;
        rmd_160: HashClass:=TDCP_ripemd160;
        tiger_192: HashClass:=TDCP_tiger;
        haval_256: HashClass:=TDCP_haval;
        sha_256: HashClass:=TDCP_sha256;
        sha_384: HashClass:=TDCP_sha384;
        sha_512: HashClass:=TDCP_sha512;
        else HashClass:=TDCP_sha1;
      end;
      Hash:=HashClass.Create(nil);
      Hash.Init;
      Input.Position:=0;
      Hash.UpdateStream(Input,Input.Size);
      Hash.Final(Digest);
      while x<(Hash.HashSize div $08) do begin
        Output+=IntToHex(Digest[Low(Digest)+x],$02);
        x+=$01;
      end;
      if Length(Output)/$02=(Hash.HashSize div $08)
        then result:=True;
      Hash.Free;
  end;
end;

end.


