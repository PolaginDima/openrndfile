program openrndfile;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Classes, SysUtils, CustApp, {FileUtil,} lconvencoding,{ lazutf8,} lazFileUtils, Crt, inifiles,
  process//, LCLProc
  { you can add units after this };

type

  { TMyOpenRNFFile }

  TMyOpenRNFFile = class(TCustomApplication)
  private
   // spisfls:tstringlist;
    function CreateINIFile:boolean;
    function AddingSlash(DIR:string):string;
    procedure GetFiles(path:string; EXTsp:array of string;astr:tstringlist);
    procedure SearchFiles(DIRsp, EXTsp:array of string; astr:tstringlist);
  protected
    procedure DoRun; override;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure WriteHelp; virtual;
  end;

{ TMyOpenRNFFile }

function TMyOpenRNFFile.CreateINIFile: boolean;
var
  tmpf:file;
  inif:tinifile;
begin
  try
      //Создадим пустой файл
      //writeln('не найден файл настроек - '+ExtractFilePath(self.ExeName) + 'nastr.ini');
      assignfile(tmpf, ExtractFilePath(self.ExeName) + 'nastr.ini');//Подключимся
      rewrite(tmpf);//создадим
      closefile(tmpf);//отключимся

      //проверим создался ли файл
      if  fileexists(ExtractFilePath(self.ExeName) + 'nastr.ini') then
      begin
        //writeln;
        //writeln('заполним настройки по умолчанию');
        //создадим экземпляр класса
        inif:=tinifile.Create(ExtractFilePath(self.ExeName) + 'nastr.ini');
        //значения по умолчанию
        inif.WriteString('paths','count','1');
        inif.WriteString('paths','path1',ExtractFileDir(self.ExeName));
        inif.WriteString('exts','count','4');
        inif.WriteString('exts','ext1','avi');
        inif.WriteString('exts','ext2','mpg');
        inif.WriteString('exts','ext3','mp4');
        inif.WriteString('exts','ext4','mov');
        inif.Free;
        //writeln;
        //writeln('настройки заполнены');
      end;
      result:=true;
  except
               on E: Exception do
               begin
                 //MessageDlg('неизвестная ошибка',e.Message,mtError,[mbOK],0) ;
                 result:=false;
               end;
  end;

end;

function TMyOpenRNFFile.AddingSlash(DIR: string): string;
begin
  if DIR[length(DIR)]<>DirectorySeparator then result:=DIR+DirectorySeparator
  else result:=DIR;
end;

procedure TMyOpenRNFFile.GetFiles(path: string; EXTsp: array of string;
  astr: tstringlist);
var j:integer;
   srd, srf:tsearchrec;
  //fl:textfile;
begin
      for j:=0 to high(EXTsp) do
      begin
        if length(EXTsp[j])>0 then
        begin
         //Ищем нужные файлы
        if findfirstutf8(self.AddingSlash(path)+'*.'+EXTsp[j], faAnyFile-faDirectory, srf)=0 then
        begin
          //если найден, то заносим в список
          astr.Append(self.AddingSlash(path)+srf.Name);
          //writeln(fl,utf8toCP866(srf.name));
          //writeln(utf8toCP866(srf.name));
          //Продолжаем поиск файлов
          while findnextutf8(srf)=0 do astr.Append(self.AddingSlash(path)+srf.Name);
                //begin
                  //writeln(fl,utf8toCP866(srf.name));
                  //writeln(utf8toCP866(srf.name));
                //end;
          findcloseutf8(srf);
        end;
       end;
      end;
      //Теперь переберем директории
        if (findfirstutf8(self.AddingSlash(path)+'*',faDirectory, srd)=0)//Поиск директории
        //не родительская
        then
        begin
          //рекурсивный вызов
          if ((srd.Attr and faDirectory)>0)
          and (srd.Name<>'.')
          and (srd.Name<>'..') then //writeln(utf8toCP866(srd.name));
               self.GetFiles(self.AddingSlash(path)+srd.Name,EXTsp,astr);
          //продолжим поиск директорий
          while ((findnextutf8(srd)=0)) do
                begin
                  if ((srd.Attr and faDirectory)>0 )
                  and (srd.Name<>'.')
                  and (srd.Name<>'..') then//writeln(utf8toCP866(srd.name));
                    self.GetFiles(self.AddingSlash(path)+srd.Name,EXTsp,astr);
                end;
        end;
        findcloseutf8(srd);
end;

procedure TMyOpenRNFFile.SearchFiles(DIRsp, EXTsp: array of string;
  astr: tstringlist);
var i:integer;
begin
  //writeln;
  //writeln;
  //assignfile(fl,  ExtractFilePath(self.ExeName) + '1.txt');//Подключимся
  //rewrite(fl);
  for i:=0 to high(DIRsp) do
  begin
    if DirectoryExistsutf8(DIRsp[i]) then
    begin
      //writeln('Ищем в '+DIRsp[i]);
      self.GetFiles(DIRsp[i],EXTsp,astr);
    end;
  end;
  //close(fl);
  //findclose(srd);
end;

procedure TMyOpenRNFFile.DoRun;
var
  ErrorMsg: String;
  inif:tinifile;
  i:integer;
  PATHs:array of string; //Здесь храним пути
  EXTs:array of string; //Здесь храним расширения
  fls:tstringlist;//Список найденных файлов
  flagexit:boolean;
  aProcess:TProcess;
begin
  // quick check parameters
  ErrorMsg:=CheckOptions('h', 'help');
  if ErrorMsg<>'' then begin
    ShowException(Exception.Create(ErrorMsg));
    Terminate;
    Exit;
  end;

  // parse parameters
  if HasOption('h', 'help') then begin
    WriteHelp;
    Terminate;
    Exit;
  end;

  { add your program here }
  flagexit:=false;
  //clrscr;//Очистим окно вывода
  //Для начала проверим наличие файла настроек, если его нет, то создадим новый шаблонный
  setlength(PATHs,3);
  if not fileexists(ExtractFilePath(self.ExeName) + 'nastr.ini') then CreateINIFile;
  //Прочитаем настройки
    try
      //writeln;
      //writeln('читаем ini файл');
      //создадим экземпляр класса
      inif:=tinifile.Create(ExtractFilePath(self.ExeName) + 'nastr.ini');
      setlength(PATHs, strtoint(inif.ReadString('paths','count','')));
      setlength(EXTs,strtoint(inif.ReadString('exts','count','')));
      //writeln(length(PATHs));
      //writeln(length(EXTs));
      for i:=0 to high(PATHs) do PATHs[i]:=CP1251toUTF8(inif.ReadString('paths','path'+inttostr(i+1),''));
      for i:=0 to high(EXTs) do EXTs[i]:=inif.ReadString('exts','ext' +inttostr(i+1),'');
  except
               on E: Exception do
               begin
                 //MessageDlg('неизвестная ошибка',e.Message,mtError,[mbOK],0) ;
                 flagexit:=true;
               end;
  end;
  if not flagexit then
  begin
    //Начнем поиск в соответствии с настройками
    fls:=tstringlist.Create;
    self.SearchFiles(PATHs,EXTs, fls);
    //Проверим нашлось ли что нибуть
    if fls.Count>0 then
    begin
      //writeln('найдено файло '+inttostr(fls.Count));
      //writeln; writeln;
      randomize;
      //writeln('случайный файл '+utf8toCP1251(fls.Strings[random(fls.count)]));
      //opendocument();
      aprocess:=TProcess.Create(nil);
      aprocess.CommandLine:='explorer.exe "'+utf8toCP1251(fls.Strings[random(fls.count)])+'"';
      //writeln(aprocess.CommandLine);
      //aprocess.Parameters.Add('D:\1.txt');//fls.Strings[random(fls.count)]);
      //aprocess.Options:=aprocess.Options-[poWaitOnExit];
      aprocess.Execute;
      aprocess.Free;
    end;
    fls.Free;
    PATHs:=nil;
    EXTs:=nil;
    //readkey;
  end;
  // stop program loop
  Terminate;
end;

constructor TMyOpenRNFFile.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  StopOnException:=True;
end;

destructor TMyOpenRNFFile.Destroy;
begin
  inherited Destroy;
end;

procedure TMyOpenRNFFile.WriteHelp;
begin
  { add your help code here }
  writeln('Usage: ', ExeName, ' -h');
end;

var
  Application: TMyOpenRNFFile;
begin
  Application:=TMyOpenRNFFile.Create(nil);
  Application.Title:='My Open random File';
  Application.Run;
  Application.Free;
end.

