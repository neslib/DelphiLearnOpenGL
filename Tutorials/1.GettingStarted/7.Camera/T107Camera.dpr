program T107Camera;

{$R *.res}

{$R *.dres}

uses
  Sample.App in '..\..\Common\Sample.App.pas',
  Sample.Platform in '..\..\Common\Sample.Platform.pas',
  App in 'App.pas',
  Sample.Classes in '..\..\Common\Sample.Classes.pas';

begin
  RunApp(TCameraApp, 800, 600, 'Camera');
end.
