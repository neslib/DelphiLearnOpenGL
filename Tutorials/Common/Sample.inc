{ Don't convert Single to Double on x64 }
{$EXCESSPRECISION OFF}

{$SCOPEDENUMS ON}

{$IF Defined(ANDROID) or Defined(IOS)}
  {$DEFINE MOBILE}
{$ENDIF}