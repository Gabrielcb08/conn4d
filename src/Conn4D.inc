{
  Conn4D.inc — switches de compilação dos engines OPCIONAIS.

  O compilador Delphi não detecta sozinho se ZeosLib/UniDAC estão instalados na
  IDE. Por isso o esquema é opt-in: ative o define APENAS se a biblioteca
  correspondente estiver instalada. Com o define desligado, a unit do engine
  compila VAZIA — incluí-la num pacote nunca quebra a compilação.

  Para ativar: remova o ponto após a chave (de "{.$DEFINE" para "{$DEFINE").
  Alternativa: declare o símbolo em Project ▸ Options ▸ Conditional defines.
}

{.$DEFINE CONN4D_ZEOS}       // ZeosLib instalado
{.$DEFINE CONN4D_UNIDAC}     // Devart UniDAC instalado
