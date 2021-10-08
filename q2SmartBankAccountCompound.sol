//SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0 <0.9.0;

interface cETH {
    function mint() external payable;

    function redeem(uint256 redeemTokens) external returns (uint256);

    function exchangeRateStored() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256 balance);
}

contract SmartBankAccountCompound {
    uint256 internal ContractBalance; // in wei

    mapping(address => uint256) balancesInCEth; // cEth in wei
    mapping(address => uint256) balances; // in wei

    //rinkeby = 0xd6801a1dffcd0a410336ef88def4320d6df1883e
    //ropsten = 0x859e9d8a4edadfedb5a2ff311243af80f85a91b8
    address COMPOUND_CETH_ADDRESS = 0x859e9d8a4edadfEDb5A2fF311243af80F85A91b8;
    cETH ceth = cETH(COMPOUND_CETH_ADDRESS);

    function addBalance() public payable {
        uint256 cEthOfContractBeforeMinting = ceth.balanceOf(address(this));
        ceth.mint{value: msg.value}();
        uint256 cEthOfContractAfterMinting = ceth.balanceOf(address(this));

        uint256 cEthOfUser = cEthOfContractAfterMinting -
            cEthOfContractBeforeMinting;
        balancesInCEth[msg.sender] += cEthOfUser;

        balances[msg.sender] += msg.value;
        ContractBalance += msg.value;
    }

    function getBalance(address userAddress) public view returns (uint256) {
        return (balancesInCEth[userAddress] * ceth.exchangeRateStored());
    }

    function withdraw(uint256 withdrawAmount) public payable returns (uint256) {
        require(withdrawAmount <= getBalance(msg.sender), "overdrawn");

        balancesInCEth[msg.sender] -= withdrawAmount;
        ContractBalance -= withdrawAmount;

        uint256 cEthOfContractBeforeRedeeming = address(this).balance;
        ceth.redeem(balancesInCEth[msg.sender]);
        uint256 cEthOfContractAfterRedeeming = address(this).balance;
        uint256 redeemable = cEthOfContractAfterRedeeming -
            cEthOfContractBeforeRedeeming;

        (bool sent, ) = payable(msg.sender).call{value: redeemable}("");
        require(sent, "Failed to send Ether");

        return redeemable;
    }

    function getContractBalance() public view returns (uint256) {
        return ContractBalance;
    }

    receive() external payable {}
}
