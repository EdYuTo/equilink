#!/usr/bin/env python3
"""Compila e serve os dois aplicativos localmente, sem publicar em lugar nenhum.

Uso:
    python ferramentas/servir.py            # compila e sobe os dois
    python ferramentas/servir.py admin      # somente o painel administrativo
    python ferramentas/servir.py usuario    # somente o aplicativo do usuário

Para apontar para um backend em vez dos dados de demonstração:
    set EQUILINK_FONTE=http
    set EQUILINK_API=https://api.exemplo.app
    python ferramentas/servir.py

Feito em Python para funcionar igual no Windows (cmd/PowerShell/Git Bash) e no
Linux, sem depender de bash nem de permissões de execução.
"""

from __future__ import annotations

import os
import posixpath
import shutil
import subprocess
import sys
import threading
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit

RAIZ = Path(__file__).resolve().parent.parent

APLICATIVOS = {
    "admin": {
        "projeto": "equilink_admin",
        "base": "/",
        "porta": 8100,
        "rotulo": "painel administrativo",
    },
    "usuario": {
        "projeto": "equilink",
        "base": "/equilink/",
        "porta": 8099,
        "rotulo": "aplicativo do usuário",
    },
}


def defines() -> list[str]:
    """Repassa a configuração de fonte para o build, quando definida."""
    argumentos = []
    for chave in (
        "EQUILINK_FONTE", "EQUILINK_API", "EQUILINK_TOKEN", "EQUILINK_SITE",
        "EQUILINK_ANALYTICS", "EQUILINK_API_EVENTOS",
    ):
        valor = os.environ.get(chave)
        if valor:
            argumentos.append(f"--dart-define={chave}={valor}")
    return argumentos


def compilar(config: dict) -> Path:
    projeto = RAIZ / config["projeto"]
    print(f"==> Compilando {config['rotulo']}", flush=True)
    comando = [
        "flutter", "build", "web", "--release",
        f"--base-href={config['base']}",
        *defines(),
    ]
    # No Windows o Flutter é um .bat; shell=True resolve a extensão.
    resultado = subprocess.run(
        comando,
        cwd=projeto,
        shell=os.name == "nt",
    )
    if resultado.returncode != 0:
        sys.exit(f"Falha ao compilar {config['rotulo']}.")
    return projeto / "build" / "web"


class ServidorSilencioso(SimpleHTTPRequestHandler):
    """Servidor de arquivos estáticos que não polui o terminal com cada GET.

    Os apps usam URL de caminho (`usePathUrlStrategy`), então `/equilink/baias`
    não é arquivo: é rota do go_router. Como nos Workers publicados, caminho sob
    a `base` que não existe e não tem extensão recebe o `index.html` do app.
    Arquivo ausente com extensão (`.js`, `.wasm`, asset) continua 404, para que
    build quebrado não passe despercebido.
    """

    def __init__(self, *args, diretorio: str, base: str = "/", **kwargs) -> None:
        # Antes do super(): o construtor da base já atende a requisição.
        self.base = base
        super().__init__(*args, directory=diretorio, **kwargs)

    def send_head(self):
        caminho = urlsplit(self.path).path
        if self._rota_do_app(caminho):
            self.path = f"{self.base}index.html"
        return super().send_head()

    def _rota_do_app(self, caminho: str) -> bool:
        if not caminho.startswith(self.base):
            return False
        if os.path.exists(self.translate_path(caminho)):
            return False
        return "." not in posixpath.basename(caminho.rstrip("/"))

    def log_message(self, formato: str, *args) -> None:  # noqa: A002
        pass


def servir(diretorio: Path, porta: int, rotulo: str, base: str) -> ThreadingHTTPServer:
    """Publica o build na raiz e, quando houver `base`, também sob esse caminho.

    O Flutter compilado com `--base-href=/x/` procura os arquivos em `/x/`, então
    o build precisa ser alcançável nesse prefixo. Serve para reproduzir
    localmente um site publicado sob subdiretório.
    """
    raiz = diretorio
    prefixo = base.strip("/")
    if prefixo:
        # Espelha o build dentro de uma pasta com o nome do subdiretório.
        espelho = diretorio.parent / f"_servido_{prefixo}"
        if espelho.exists():
            shutil.rmtree(espelho)
        destino = espelho / prefixo
        shutil.copytree(diretorio, destino)
        raiz = espelho

    manipulador = partial(ServidorSilencioso, diretorio=str(raiz), base=base)
    servidor = ThreadingHTTPServer(("127.0.0.1", porta), manipulador)
    threading.Thread(target=servidor.serve_forever, daemon=True).start()
    print(f"==> {rotulo}: http://127.0.0.1:{porta}{base}", flush=True)
    return servidor


def main() -> None:
    alvo = sys.argv[1] if len(sys.argv) > 1 else "ambos"
    if alvo not in ("ambos", "admin", "usuario"):
        sys.exit("Uso: python ferramentas/servir.py [ambos|admin|usuario]")

    escolhidos = list(APLICATIVOS.values()) if alvo == "ambos" else [APLICATIVOS[alvo]]

    servidores = []
    for config in escolhidos:
        destino = compilar(config)
        servidores.append(servir(destino, config["porta"], config["rotulo"], config["base"]))

    print("\nServindo. Ctrl+C encerra.", flush=True)
    try:
        for s in servidores:
            s.serve_forever()
    except KeyboardInterrupt:
        for s in servidores:
            s.shutdown()


if __name__ == "__main__":
    main()
