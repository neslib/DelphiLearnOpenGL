program T403aBlendingDiscard;

{$R *.res}

{$R *.dres}

uses
  Sample.App in '..\..\Common\Sample.App.pas',
  Sample.Platform in '..\..\Common\Sample.Platform.pas',
  App in 'App.pas',
  Sample.Classes in '..\..\Common\Sample.Classes.pas',
  Sample.Common in '..\..\Common\Sample.Common.pas';

begin
  RunApp(TBlendingDiscardApp, 800, 600, 'Blending - Discarding Fragments');
end.
