unit uutility;

{
    XA80 - Cross Assembler for x80 processors
    Copyright (C)2020-2022 Duncan Munro

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.

    Contact: Duncan Munro  duncan@duncanamps.com
}


{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, CustApp;

procedure AugmentIncludes(s: string; list: TStringList);
function  BinaryStrToInt(_str: string): integer;
function  BinToDecStr(_s: string): string;
function  BooleanToYN(_b: boolean): string;
function  CharAsReadable(_c: char): string;
procedure CmdOptionToList(app: TCustomApplication; shortopt: char; longopt: string; list: TStringList; delim: boolean = False);
function  ExpandTabs(const _s: string; tabsize: integer): string;
function  Indirected(_str: string): boolean;
function  InQuotes(const _s: string): boolean;
function  IntToBinaryStr(_v: integer; _digits: integer): string;
function  IntToOctalStr(_v: integer; _digits: integer): string;
function  IsPrime(_value: integer): boolean;
function  LineTerminator: string;
function  NCSPos(_a, _b: string): integer;
function  NextPrime(_value: integer): integer;
function  OctalStrToInt(_str: string): integer;
function  OctToDecStr(_s: string): string;
function  ProgramData: string;
procedure UnderlinedText(_sl: TStringList; _text: string; _blank_after: boolean = True; _underline_char: char = '-');
function  UnEscape(_s: string): string;

implementation

uses
{$IFDEF WINDOWS}
  WinDirs,
{$ENDIF}
  uasmglobals;

procedure AugmentIncludes(s: string; list: TStringList);
begin
  {%H-}s := IncludeTrailingPathDelimiter(s);
  if list.IndexOf(s) < 0 then
    list.Insert(0,s);
end;

function BinaryStrToInt(_str: string): integer;
begin
  Result := 0;
  while _str <> '' do
    begin
      Result := Result shl 1;
      Result := Result + StrToInt(_str[1]);
      Delete(_str,1,1);
    end;
end;

function BinToDecStr(_s: string): string;
var i: integer;
    v: integer;
begin
  v := 0;
  for i := 3 to Length(_s) do // Start at 3 to skip the '0b' at the start
    begin
      v := v * 2;
      v := v + Ord(_s[i]) - Ord('0');
    end;
  result := IntToStr(v);
end;

function BooleanToYN(_b: boolean): string;
begin
  if _b then
    BooleanToYN := 'Y'
  else
    BooleanToYN := 'N';
end;

function CharAsReadable(_c: char): string;
begin
  case _c of
    #0:  Result := 'NUL';
    #1:  Result := 'SOH';
    #2:  Result := 'STX';
    #3:  Result := 'ETX';
    #4:  Result := 'EOT';
    #5:  Result := 'ENQ';
    #6:  Result := 'ACK';
    #7:  Result := 'BEL';
    #8:  Result := 'BS';
    #9:  Result := 'HT';
    #10: Result := 'LF';
    #11: Result := 'VT';
    #12: Result := 'FF';
    #13: Result := 'CR';
    #14: Result := 'SO';
    #15: Result := 'SI';
    #16: Result := 'DLE';
    #17: Result := 'DC1';
    #18: Result := 'DC2';
    #19: Result := 'DC3';
    #20: Result := 'DC4';
    #21: Result := 'NAK';
    #22: Result := 'SYN';
    #23: Result := 'ETB';
    #24: Result := 'CAN';
    #25: Result := 'EM';
    #26: Result := 'SUB';
    #27: Result := 'ESC';
    #28: Result := 'FS';
    #29: Result := 'GS';
    #30: Result := 'RS';
    #31: Result := 'US';
    #32: Result := 'SPC';
    '!'..'~': Result := _c;
    #127:     Result := 'DEL';
    otherwise
      Result := IntToStr(Ord(_c));
  end;
end;

procedure CmdOptionToList(app: TCustomApplication; shortopt: char; longopt: string; list: TStringList; delim: boolean = False);
var i: integer;
begin
  if app.HasOption(shortopt,longopt) then
    begin
      list.Delimiter := ';';
      list.DelimitedText := app.GetOptionValue(shortopt,longopt);
      if delim then for i := 0 to list.Count-1 do
        list[i] := IncludeTrailingPathDelimiter(ExpandFilename(list[i]));
    end;
end;

function ExpandTabs(const _s: string; tabsize: integer): string;
var i: integer;
    amt: integer;
begin
  Result := '';
  for i := 1 to Length(_s) do
    begin
      if _s[i] <> #9 then
        Result := Result + _s[i]
      else
        begin
          amt := Length(Result) mod tabsize;
          amt := tabsize - amt;
          Result := Result + Space(amt);
        end;
    end;
end;

procedure IdentifyStringPos(const _src: string; var _start,_length: integer);
type TISPState = (stNormal,stDQStr,stDQEsc,stSQStr,stSQEsc);
var state: TISPState;
    ch:    char;
    index: integer;
    srclen: integer;
    done:   boolean;
begin
  state   := stNormal;
  srclen  := Length(_src);
  index   := 1;
  _start  := 0;
  _length := 0;
  done    := False;
  while (index <= srclen) and (not done) do
    begin
      ch := _src[index];
      case state of
        stNormal: case ch of
                    SQ: begin
                          state := stSQStr;
                          _start := index;
                        end;
                    DQ: begin
                          state := stDQStr;
                          _start := index;
                        end;
                  end;
        stDQStr: case ch of
                    DQ: begin
                          state := stNormal;
                          done  := True;
                          _length := index - _start + 1;
                        end;
                    ESCAPE: state := stDQEsc;
                  end;
        stDQEsc: if ch in ESCAPED then
                    state := stDQStr
                  else
                    raise Exception.Create('Illegal escape character ' + ch);
        stSQStr: case ch of
                    SQ: begin
                          state := stNormal;
                          done  := True;
                          _length := index - _start + 1;
                        end;
                    ESCAPE: state := stSQEsc;
                  end;
        stSQEsc: if ch in ESCAPED then
                    state := stSQStr
                  else
                    raise Exception.Create('Illegal escape character ' + ch);
      end;
      Inc(index);
    end;
end;

// Return True if an operand is Indirected, e.g.
//
// (HL)                   True
// 1+(C)                  False
// (IX+3)                 True
// (0x03ab)               True
// (buffer)               True
// (buffer+1)*(2+3)       False
// (buffer+ASC(")"))      True
// (ASC(LEFT("3\"))",1))) True

function Indirected(_str: string): boolean;
var i: integer;
    ch: char;
    sp: integer;
    sl: integer;
    brace_count: integer;
    brace_min:   integer;
begin
  Indirected := False;
  if (Length(_str) >= 3) and
     (LeftStr(_str,1) = '(') and
     (RightStr(_str,1) = ')') then
    begin
      sp := 0;
      sl := 0;
      repeat
        IdentifyStringPos(_str,sp,sl);
        if sp > 0 then
          Delete(_str,sp,sl);
      until sp < 1;
      brace_count := 0;
      brace_min   := 1;
      for i := 1 to Length(_str) do
        begin
          ch := _str[i];
          if ch = '(' then
            Inc(brace_count)
          else if ch = ')' then
            begin
              Dec(brace_count);
              if (brace_count < brace_min) and (i < Length(_str)) then
                brace_min := brace_count;
            end;
        end;
      if brace_count <> 0 then
        raise Exception.Create('Mismatched parenthesis in operand');
      Indirected := (brace_min > 0);
    end;
end;

function InQuotes(const _s: string): boolean;
begin
  Result := (Length(_s) >= 2) and ((_s[1] = '''') or (_s[1] = '"'));
end;

function IntToBinaryStr(_v: integer; _digits: integer): string;
begin
  Result := '';
  while _v > 0 do
    begin
      Result := IntToStr(_v and $01) + Result;
      _v := _v shr 1;
    end;
  while Length(Result) < _digits do
    Result := '0' + Result;
end;

function IntToOctalStr(_v: integer; _digits: integer): string;
begin
  Result := '';
  while _v > 0 do
    begin
      Result := IntToStr(_v and $07) + Result;
      _v := _v shr 3;
    end;
  while Length(Result) < _digits do
    Result := '0' + Result;
end;

function IsPrime(_value: integer): boolean;
var divisor: integer;
begin
  divisor := 3;
  Result := True;
  if (_value > 3) and ((_value mod 2) = 0) then
    Exit(False);  // Even numbers > 2 aren't prime
  while divisor*divisor < _value do
    if (_value mod divisor) = 0 then
      Exit(False)
    else
      divisor := divisor + 2;
end;

function LineTerminator: string;
begin
{$IFDEF WINDOWS}
  Result := #13 + #10;
{$ELSE}
  Result := #10;
{$ENDIF}
end;

function NCSPos(_a, _b: string): integer;
begin
  NCSPos := Pos(UpperCase(_a),UpperCase(_b));
end;

function NextPrime(_value: integer): integer;
begin
  if (_value mod 2) = 0 then
    Inc(_value);
  while not IsPrime(_value) do
    _value := _value + 2;
  Result := _value;
end;

function OctalStrToInt(_str: string): integer;
begin
  Result := 0;
  while _str <> '' do
    begin
      Result := Result shl 3;
      Result := Result + StrToInt(_str[1]);
      Delete(_str,1,1);
    end;
end;

function OctToDecStr(_s: string): string;
var i: integer;
    v: integer;
begin
  v := 0;
  for i := 2 to Length(_s) do // Start at 2 to skip the '0' at the start
    begin
      v := v * 8;
      v := v + Ord(_s[i]) - Ord('0');
    end;
  result := IntToStr(v);
end;

function ProgramData: string;
var folder: string;
begin
{$IFDEF WINDOWS}
  folder := IncludeTrailingPathDelimiter(GetWindowsSpecialDir(CSIDL_LOCAL_APPDATA));
  {$DEFINE PROGRAMDATA_DEFINED}
{$ENDIF}
{$IFDEF LINUX}
  folder := IncludeTrailingPathDelimiter(GetAppConfigDir(False));
  {$DEFINE PROGRAMDATA_DEFINED}
  {$ENDIF}
{$IFNDEF PROGRAMDATA_DEFINED}
  ERROR OPERATING SYSTEM NOT CATERED FOR
{$ENDIF}
  folder := IncludeTrailingPathDelimiter(folder + 'XA80');
  ForceDirectories(folder); // Ensure directory exists!
  Result := folder;
end;

procedure UnderlinedText(_sl: TStringList; _text: string; _blank_after: boolean = True; _underline_char: char = '-');
begin
  _sl.Add(_text);
  _sl.Add(StringOfChar(_underline_char,Length(_text)));
  if _blank_after then
    _sl.Add('');
end;

{ Remove enclosing ' or " if present. Turn escape characters into real ones }

function UnEscape(_s: string): string;
const ESCAPE_PREFIX = '\';
var ch: char;
    i:  integer;
begin
  Result := '';
  if InQuotes(_s) then
    _s := Copy(_s,2,Length(_s)-2); // Remove enclosing quotes
  i := 1;
  while i <= Length(_s) do
    begin
      ch := _s[i];
      if ch = ESCAPE_PREFIX then
        begin
          if i = Length(_s) then
            raise Exception.Create('No character present after escape prefix');
          Inc(i);
          ch := _s[i];
          case ch of
            '\': Result := Result + '\';
            #34: Result := Result + #34;
            #39: Result := Result + #39;
            't': Result := Result + #9;
            'n': Result := Result + #10;
            'r': Result := Result + #13;
            otherwise
              raise Exception.Create(Format('Illegal escape sequence %s',[ESCAPE_PREFIX + ch]));
          end; // case
        end
      else
        Result := Result + ch;
      Inc(i);
    end;
end;


end.

