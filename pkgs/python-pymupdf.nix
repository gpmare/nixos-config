# PyMuPDF 1.28.2 is not in nixpkgs (pinned there at 1.27.2.3, with
# pymupdf4llm still at 0.3.4 and no pymupdf-layout). These are the
# manylinux wheels from PyPI. abi3 / py3 wheels load on this system's
# Python 3.14. libmupdf is bundled in the pymupdf wheel; the layout
# extensions link it from that package via RPATH.
{
  lib,
  fetchurl,
  python3,
  stdenv,
  glibc,
  autoPatchelfHook,
}:

let
  py = python3.pkgs;

  pymupdf = py.buildPythonPackage rec {
    pname = "pymupdf";
    version = "1.28.2";
    format = "wheel";

    src = fetchurl {
      url = "https://files.pythonhosted.org/packages/c7/06/dace3e27af26690cb20bead80dbac42941b0841eb689b8aabbd67dde16f0/pymupdf-1.28.2-cp310-abi3-manylinux_2_28_x86_64.whl";
      hash = "sha256-OX1nFcHw33VIqS0K/YzjcPxI+keu76wWvivAShaoIn8=";
    };

    nativeBuildInputs = [ autoPatchelfHook ];
    buildInputs = [
      stdenv.cc.cc.lib
      glibc
    ];

    dontStrip = true;

    preFixup = ''
      addAutoPatchelfSearchPath $out/${python3.sitePackages}/pymupdf
    '';

    pythonImportsCheck = [ "pymupdf" ];

    meta = {
      description = "Python bindings for MuPDF";
      homepage = "https://pymupdf.readthedocs.io/";
      license = lib.licenses.agpl3Plus;
      platforms = [ "x86_64-linux" ];
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    };
  };

  pymupdf-layout = py.buildPythonPackage rec {
    pname = "pymupdf-layout";
    version = "1.28.2";
    format = "wheel";

    src = fetchurl {
      url = "https://files.pythonhosted.org/packages/03/65/6b92d25678c64839fb2066ee98d6d1f164d820ba045d83c77e79021cda98/pymupdf_layout-1.28.2-cp310-abi3-manylinux_2_28_x86_64.whl";
      hash = "sha256-S0Sh2Ov4l7DoYu4tc+ffcwmfHAR/wCTS3STvBjLSy18=";
    };

    nativeBuildInputs = [ autoPatchelfHook ];
    buildInputs = [
      stdenv.cc.cc.lib
      glibc
    ];

    dependencies = [
      pymupdf
      py.pyyaml
      py.numpy
      py.onnxruntime
      py.networkx
      py.sympy
    ];

    dontStrip = true;

    preFixup = ''
      addAutoPatchelfSearchPath $out/${python3.sitePackages}/pymupdf
      addAutoPatchelfSearchPath ${pymupdf}/${python3.sitePackages}/pymupdf
    '';

    # pymupdf.layout is only importable once this tree is merged with the
    # pymupdf package (regular package, not a namespace). The env does that.
    pythonImportsCheck = [ ];

    meta = {
      description = "Layout analysis for PyMuPDF";
      homepage = "https://pymupdf.readthedocs.io/";
      license = lib.licenses.agpl3Plus;
      platforms = [ "x86_64-linux" ];
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    };
  };

  pymupdf4llm = py.buildPythonPackage rec {
    pname = "pymupdf4llm";
    version = "1.28.2";
    format = "wheel";

    src = fetchurl {
      url = "https://files.pythonhosted.org/packages/7d/93/0ec4c33150f127d19b306d876b969755f02ed721f3a9337fd1f4fe4a1c85/pymupdf4llm-1.28.2-py3-none-any.whl";
      hash = "sha256-VcBsB9Eo+UxNknG9Qn0W7iGXeefXlqe52k4RC+MATZY=";
    };

    dependencies = [
      pymupdf
      pymupdf-layout
      py.tabulate
      py.psutil
    ];

    # Both wheels install into the pymupdf namespace (core vs layout/).
    catchConflicts = false;

    # Same merge: importing this loads pymupdf.layout from the combined tree.
    pythonImportsCheck = [ ];

    meta = {
      description = "PDF to Markdown for PyMuPDF";
      homepage = "https://pymupdf.readthedocs.io/";
      license = lib.licenses.agpl3Plus;
      sourceProvenance = [ lib.sourceTypes.fromSource ]; # pure python wheel
    };
  };
in
{
  inherit pymupdf pymupdf-layout pymupdf4llm;
}
