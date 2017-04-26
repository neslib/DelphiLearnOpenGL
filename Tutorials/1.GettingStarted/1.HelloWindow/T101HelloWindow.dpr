program T101HelloWindow;

{$R *.res}

uses
  Sample.App in '..\..\Common\Sample.App.pas',
  Sample.Platform in '..\..\Common\Sample.Platform.pas',
  App in 'App.pas',
  Sample.Classes in '..\..\Common\Sample.Classes.pas',
  Sample.Androidapi.AppGlue in '..\..\Common\Sample.Androidapi.AppGlue.pas';

begin
  RunApp(THelloWindowApp, 800, 600, 'Hello Window');
end.
