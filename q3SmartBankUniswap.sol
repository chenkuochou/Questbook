//SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0 <0.9.0;

interface cETH {
    function mint() external payable;

    function redeem(uint256 redeemTokens) external returns (uint256);

    function exchangeRateStored() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256 balance);
}

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

// @Uniswap/v2-periphery/blob/master/contracts/interfaces
pragma solidity >=0.6.2;

interface IUniswapV2Router01 {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

interface IUniswapV2Router02 is IUniswapV2Router01 {
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

pragma solidity >=0.7.0 <0.9.0;

contract SmartBankUniswap {
    uint256 ContractBalance = 0; // in wei

    address COMPOUND_CETH_ADDRESS = 0x859e9d8a4edadfEDb5A2fF311243af80F85A91b8;
    cETH ceth = cETH(COMPOUND_CETH_ADDRESS);

    address UNISWAP_ROUTER_ADDRESS = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    IUniswapV2Router02 uniswap = IUniswapV2Router02(UNISWAP_ROUTER_ADDRESS);

    mapping(address => uint256) balances;
    mapping(address => uint256) balancesInCeth;

    //mapping(address => uint256) test;

    function addBalance() public payable {
        uint256 cEthBeforeMinting = ceth.balanceOf(address(this));
        ceth.mint{value: msg.value}();
        uint256 cEthAfterMinting = ceth.balanceOf(address(this));

        uint256 cEthOfUser = cEthAfterMinting - cEthBeforeMinting;
        balancesInCeth[msg.sender] += cEthOfUser;

        balances[msg.sender] += msg.value;
        ContractBalance += msg.value;
    }

    function addBalanceERC20(address erc20Address) public {
        IERC20 erc20 = IERC20(erc20Address);

        // how many erc20tokens has the user (msg.sender) approved this contract to use?
        uint256 approvedERC20Amount = erc20.allowance(
            msg.sender,
            address(this)
        );

        // transfer all those tokens that had been approved by user (msg.sender) to the smart contract (address(this))
        erc20.transferFrom(msg.sender, address(this), approvedERC20Amount);

        erc20.approve(UNISWAP_ROUTER_ADDRESS, approvedERC20Amount);

        address token = erc20Address;
        // uint256 amountETHMin = 0;
        // address to = address(this);
        // uint256 deadline = block.timestamp + (24 * 60 * 60);
        address[] memory path = new address[](2);
        path[0] = token;
        path[1] = uniswap.WETH(); // check uniswap.exchange

        uniswap.swapExactTokensForETH(
            approvedERC20Amount,
            0,
            path,
            address(this),
            block.timestamp + (24 * 60 * 60)
        );
        //TODO : rest of the logic
        // 3. deposit eth to compound
    }

    function swapTokens(address erc20TokenAddress) public payable {}

    function depositToCompound() public payable {}

    function withdraw(uint256 withdrawAmount) public payable returns (uint256) {
        require(withdrawAmount <= getBalance(msg.sender), "overdrawn");

        balances[msg.sender] -= withdrawAmount;
        ContractBalance -= withdrawAmount;

        uint256 EthBeforeRedeeming = address(this).balance;
        ceth.redeem(balancesInCeth[msg.sender]);
        uint256 EthAfterRedeeming = address(this).balance;
        uint256 redeemable = EthAfterRedeeming - EthBeforeRedeeming;

        (bool sent, ) = payable(msg.sender).call{value: redeemable}("");
        require(sent, "Failed to send Ether");

        return redeemable;
    }

    receive() external payable {}

    // sanity check
    function getAllowanceERC20(address erc20Address)
        public
        view
        returns (uint256)
    {
        IERC20 erc20 = IERC20(erc20Address);
        return erc20.allowance(msg.sender, address(this));
    }

    function getbalanceERC20(address erc20Address)
        public
        view
        returns (uint256)
    {
        IERC20 erc20 = IERC20(erc20Address);
        return erc20.balanceOf(address(this));
    }

    // viewing functions
    function getBalance(address userAddress) public view returns (uint256) {
        return (balancesInCeth[userAddress] * ceth.exchangeRateStored());
    }

    function getCethBalance(address userAddress) public view returns (uint256) {
        return balancesInCeth[userAddress];
    }

    function getExchangeRate() public view returns (uint256) {
        return ceth.exchangeRateStored();
    }

    function getContractBalance() public view returns (uint256) {
        return ContractBalance;
    }

    function addMoneyToContract() public payable {
        ContractBalance += msg.value;
    }
}

// addresses
// Compound on rinkeby = 0xd6801a1dffcd0a410336ef88def4320d6df1883e
// Compound on ropsten = 0x859e9d8a4edadfedb5a2ff311243af80f85a91b8
// dai on rinkeby = 0xc7ad46e0b8a400bb3c915120d284aafba8fc4735
// dai on ropsten = 0xad6d458402f60fd3bd25163575031acdce07538d