// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CadeiaDeSuprimentos {
    
    enum Status { Fabricado, Enviado, EmTransito, Entregue }

    struct HistoricoStatus {
        string statusTexto;
        uint data;
    }

    struct Produto {
        uint id;
        string nome;
        address fabricante;
        address donoAtual;
        Status status;
        mapping(address => bool) entidadesAutorizadas;
        HistoricoStatus[] historicoStatus; 
    }
    
    uint public contadorProdutos = 0;
    mapping(uint => Produto) public produtos;
    mapping(string => bool) private nomesProdutos;

    event ProdutoAdicionado(uint idProduto, string nome, address indexed fabricante);
    event StatusAtualizado(uint idProduto, Status novoStatus);
    event PropriedadeTransferida(uint idProduto, address indexed novoDono);
    event AutorizacaoConcedida(uint idProduto, address indexed entidadeAutorizada);

    modifier apenasDonoAtual(uint _idProduto) {
        require(msg.sender == produtos[_idProduto].donoAtual, "Somente o dono atual pode realizar esta acao");
        _;
    }

    modifier apenasAutorizados(uint _idProduto) {
        require(produtos[_idProduto].entidadesAutorizadas[msg.sender] == true, "Nao autorizado para atualizar status");
        _;
    }
    
    // Faz a verificacao se o produto já foi adicionado
    function adicionarProduto(string memory _nome) public returns (uint) {
        require(!nomesProdutos[_nome], "Produto com este nome ja existe");
        
        contadorProdutos++;
        Produto storage novoProduto = produtos[contadorProdutos];
        novoProduto.id = contadorProdutos;
        novoProduto.nome = _nome;
        novoProduto.fabricante = msg.sender;
        novoProduto.donoAtual = msg.sender;
        novoProduto.status = Status.Fabricado;
        novoProduto.entidadesAutorizadas[msg.sender] = true;
        novoProduto.historicoStatus.push(HistoricoStatus(statusParaString(Status.Fabricado), block.timestamp));
        nomesProdutos[_nome] = true;
        
        emit ProdutoAdicionado(contadorProdutos, _nome, msg.sender);
        return contadorProdutos;
    }

    // Autoriza uma entidade a atualizar o status do produto
    function autorizarEntidade(uint _idProduto, address _entidade) public apenasDonoAtual(_idProduto) {
        produtos[_idProduto].entidadesAutorizadas[_entidade] = true;
        emit AutorizacaoConcedida(_idProduto, _entidade);
    }

    // Atualiza o status do produto
    function atualizarStatus(uint _idProduto, string memory _status) public apenasAutorizados(_idProduto) {
        Status novoStatus = stringParaStatus(_status);
        
        if (produtos[_idProduto].historicoStatus.length > 0) {
            string memory ultimoStatus = produtos[_idProduto].historicoStatus[produtos[_idProduto].historicoStatus.length - 1].statusTexto;
            require(keccak256(abi.encodePacked(ultimoStatus)) != keccak256(abi.encodePacked(statusParaString(novoStatus))), "O mesmo status nao pode ser adicionado consecutivamente");
        }
        
        produtos[_idProduto].status = novoStatus;
        produtos[_idProduto].historicoStatus.push(HistoricoStatus(statusParaString(novoStatus), block.timestamp)); // Adiciona ao histórico
        emit StatusAtualizado(_idProduto, novoStatus);
    }

    function stringParaStatus(string memory _status) private pure returns (Status) {
        bytes32 statusHash = keccak256(abi.encodePacked(_status));
        
        if (statusHash == keccak256("Fabricado")) {
            return Status.Fabricado;
        } else if (statusHash == keccak256("Enviado")) {
            return Status.Enviado;
        } else if (statusHash == keccak256("EmTransito")) {
            return Status.EmTransito;
        } else if (statusHash == keccak256("Entregue")) {
            return Status.Entregue;
        } else {
            revert("Status invalido");
        }
    }

    function statusParaString(Status _status) private pure returns (string memory) {
        if (_status == Status.Fabricado) {
            return "Fabricado";
        } else if (_status == Status.Enviado) {
            return "Enviado";
        } else if (_status == Status.EmTransito) {
            return "EmTransito";
        } else if (_status == Status.Entregue) {
            return "Entregue";
        } else {
            return "Desconhecido";
        }
    }

    // Transfere a propriedade do produto para a próxima entidade na cadeia
    function transferirPropriedade(uint _idProduto, address _novoDono) public apenasDonoAtual(_idProduto) {
        produtos[_idProduto].donoAtual = _novoDono;
        produtos[_idProduto].entidadesAutorizadas[_novoDono] = true;
        emit PropriedadeTransferida(_idProduto, _novoDono);
    }
    
    // Consulta informações sobre um produto
    function obterProduto(uint _idProduto) public view returns (string memory, address, address, string memory) {
        Produto storage produto = produtos[_idProduto];
        return (produto.nome, produto.fabricante, produto.donoAtual, statusParaString(produto.status));
    }
    
    function obterHistoricoStatus(uint _idProduto) public view returns (HistoricoStatus[] memory) {
        return produtos[_idProduto].historicoStatus;
    }
    
    function estaAutorizado(uint _idProduto, address _entidade) public view returns (bool) {
        return produtos[_idProduto].entidadesAutorizadas[_entidade];
    }
}
