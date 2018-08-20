unit CRT;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, UGetMacAdress, UGetIPAdress, HTTPSend, ssl_openssl, Process,
  LCLType, lclintf;

type

  { Twindow }

  Twindow = class(TForm)
    Button1: TButton;
    Button2: TButton;
    cancelButton: TButton;
    teacher: TCheckBox;
    internet: TCheckBox;
    macInput: TEdit;
    ipInput: TEdit;
    room: TEdit;
    machineName: TEdit;
    l1: TLabel;
    l2: TLabel;
    l3: TLabel;
    l4: TLabel;
    l5: TLabel;
    registerLabel2: TLabel;
    registerButton: TButton;
    registerLabel1: TLabel;
    registrationBox: TGroupBox;
    machineBox: TGroupBox;
    versionLabel: TLabel;
    unameLabel: TLabel;
    passwordLabel: TLabel;
    infoLabel1: TLabel;
    uname: TEdit;
    pw: TEdit;
    accessBox: TGroupBox;
    logo: TImage;
    captionLabel1: TLabel;
    captionLabel2: TLabel;
    procedure cancelButtonClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure registerButtonClick(Sender: TObject);
    procedure teacherChange(Sender: TObject);
  private
    //Konfigurationsdatei lesen
    procedure parseConfigFile;
    procedure offerReboot;
    function sendRequest(url, params: string): string;
    function MemStreamToString(Strm: TMemoryStream): AnsiString;
  public
    { public declarations }
  end;

var
  window: Twindow;
  mac, ip, serverURL: string;

implementation

{$R *.lfm}

{ Twindow }

procedure Twindow.FormCreate(Sender: TObject);
var
  version, build: string;
  MacAddr: TGetMacAdress;
  IPAddr: TGetIPAdress;
begin
  version:='1.1.4';
  //build:='1B031';
  {$IFDEF WIN32}
    versionLabel.Caption:='PhilleConnect ClientRegistrationTool Win32 v'+version+' by Johannes Kreutz';
  {$ENDIF}
  {$IFDEF WIN64}
    versionLabel.Caption:='PhilleConnect ClientRegistrationTool Win64 v'+version+' by Johannes Kreutz';
  {$ENDIF}
  {$IFDEF LINUX}
    versionLabel.Caption:='PhilleConnect ClientRegistrationTool Linux v'+version+' by Johannes Kreutz';
  {$ENDIF}
  {$IFDEF DARWIN}
    versionLabel.Caption:='PhilleConnect ClientRegistrationTool macOS v'+version+' by Johannes Kreutz';
  {$ENDIF}
  MacAddr:=TGetMacAdress.create;
  mac:=MacAddr.getMac;
  MacAddr.free;
  IPAddr:=TGetIPAdress.create;
  ip:=IPAddr.getIP;
  IPAddr.free;
  macInput.text:=mac;
  ipInput.text:=ip;
  parseConfigFile;
end;

procedure Twindow.cancelButtonClick(Sender: TObject);
begin
  uname.text:='';
  pw.text:='';
  room.text:='';
  machineName.text:='';
  teacher.checked:=false;
  internet.checked:=false;
  internet.enabled:=true;
end;

procedure Twindow.registerButtonClick(Sender: TObject);
var
  response, t, i, os: string;
begin
  if (teacher.checked = true) then begin
    t:='1';
  end
  else begin
    t:='0';
  end;
  if (internet.checked = true) then begin
    i:='1';
  end
  else begin
    i:='0';
  end;
  {$IFDEF WINDOWS}
    os:='win';
  {$ENDIF}
  {$IFDEF LINUX}
    os:='linux';
  {$ENDIF}
  response:=SendRequest('https://'+serverURL+'/register.php', 'uname='+uname.text+'&pw='+pw.text+'&mac='+macInput.text+'&ip='+ipInput.text+'&room='+room.text+'&name='+machineName.text+'&teacher='+t+'&inet='+i+'&os='+os);
  pw.text:='';
  if (response = 'noaccess') then begin
    showMessage('Nutzername / Passwort falsch. Bitte erneut versuchen.');
    uname.text:='';
  end
  else if (response = 'notnew') then begin
    showMessage('Der Client wurde bereits registriert.');
    offerReboot;
  end
  else if (response = 'success') then begin
    showMessage('Der Client wurde erfolgreich registriert. Für Windows und Linux wurde das Standartprofil zugewiesen. Dies kann in der Administrationsoberfläche geändert werden.');
    offerReboot;
  end
  else if (response = 'error') then begin
    showMessage('Es ist ein Serverfehler aufgetreten. Bitte erneut versuchen.');
  end
  else if (response = 'success_room_both') then begin
    showMessage('Der Client wurde erfolgreich registriert und das Profil '+room.text+' wurde für Windows und Linux zugewiesen. Dies kann in der Administrationsoberfläche geändert werden.');
    offerReboot;
  end
  else if (response = 'success_room_win') then begin
    showMessage('Der Client wurde erfolgreich registriert und das Profil '+room.text+' wurde für Windows zugewiesen. Linux erhält das Standartprofil. Dies kann in der Administrationsoberfläche geändert werden.');
    offerReboot;
  end
  else if (response = 'success_room_linux') then begin
    showMessage('Der Client wurde erfolgreich registriert und das Profil '+room.text+' wurde für Linux zugewiesen. Windows erhält das Standartprofil. Dies kann in der Administrationsoberfläche geändert werden.');
    offerReboot;
  end
  else begin
    showMessage('Es ist ein Fehler aufgetreten. Bitte erneut versuchen.');
  end;
end;

procedure Twindow.offerReboot;
var
  process: TProcess;
begin
  if (MessageBox(window.handle, 'Nach der Installation von PhilleConnect ist ein Neustart notwendig. Möchten Sie den Computer jetzt neu starten?', 'Neustart erforderlich', MB_YESNO) = ID_YES) then begin
    process:=TProcess.create(nil);
    {$IFDEF WINDOWS}
    process.executable:='cmd';
    process.parameters.add('/C shutdown /r /f /t 0');
    {$ENDIF}
    {$IFDEF LINUX}
    process.executable:='sh';
    process.parameters.add('-c');
    process.parameters.add('reboot');
    {$ENDIF}
    process.showWindow:=swoHIDE;
    process.execute;
    process.free;
    halt;
  end
  else begin
    halt;
  end;
end;

procedure Twindow.teacherChange(Sender: TObject);
begin
  if (teacher.checked = true) then begin
    internet.enabled:=false;
    internet.checked:=true;
  end
  else begin
    internet.enabled:=true;
  end;
end;

procedure Twindow.parseConfigFile;
var
  config: TStringList;
  c: integer;
  value: TStringList;
begin
  config:=TStringList.create;
  {$IFDEF WINDOWS}
    config.loadFromFile('C:\Program Files\PhilleConnect\pcconfig.jkm');
  {$ENDIF}
  {$IFDEF DARWIN}
    config.loadFromFile(getUserDir+'pcconfig.jkm');
  {$ENDIF}
  {$IFDEF LINUX}
    config.loadFromFile('/etc/pcconfig.jkm');
  {$ENDIF}
  c:=0;
  while (c < config.count) do begin
    if (pos('#', config[c]) = 0) then begin
      value:=TStringList.create;
      value.clear;
      value.strictDelimiter:=true;
      value.delimiter:='=';
      value.delimitedText:=config[c];
      case value[0] of
        'server':
          serverURL:=value[1];
      end;
    end;
    c:=c+1;
  end;
end;

function Twindow.sendRequest(url, params: string): string;
var
   Response: TMemoryStream;
begin
   Response := TMemoryStream.Create;
   try
      if HttpPostURL(url, params, Response) then
         result:=MemStreamToString(Response);
   finally
      Response.Free;
   end;
end;

function Twindow.MemStreamToString(Strm: TMemoryStream): AnsiString;
begin
   if Strm <> nil then begin
      Strm.Position := 0;
      SetString(Result, PChar(Strm.Memory), Strm.Size);
   end;
end;

end.

