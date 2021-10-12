//SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0 <0.9.0;

interface cETH {
    function mint() external payable;

    function redeem(uint256 redeemTokens) external returns (uint256);

    function exchangeRateStored() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256 balance);
}

contract SmartBankCompound {
    uint256 internal contractBalance; // pool ETH in wei

    mapping(address => uint256) balances; // user ETH in wei

    //rinkeby = 0xd6801a1dffcd0a410336ef88def4320d6df1883e
    //ropsten = 0x859e9d8a4edadfedb5a2ff311243af80f85a91b8
    address _cEtherContract = 0x859e9d8a4edadfEDb5A2fF311243af80F85A91b8;
    cETH ceth = cETH(_cEtherContract);

    function addBalance() public payable {
        balances[msg.sender] += msg.value;
        contractBalance += msg.value;

        ceth.mint{value: msg.value}();
    }

    function withdraw(uint256 withdrawAmount) public payable returns (uint256) {
        require(withdrawAmount <= getUserEth(), "overdrawn");

        contractBalance -= withdrawAmount;

        //uint256 ethBefore = address(this).balance;

        uint256 cethToRedeem = getTotalEthFromCeth() *
            (withdrawAmount / contractBalance);

        uint256 transferable = ceth.redeem(cethToRedeem);

        // uint256 cethToRedeemTest = getUserEth() *
        //     (withdrawAmount / balances[msg.sender]);
        // ceth.redeem(cethToRedeem);

        //uint256 ethAfter = address(this).balance;
        //uint256 redeemable = ethAfter - ethBefore;

        (bool sent, ) = payable(msg.sender).call{value: transferable}("");
        require(sent, "Failed to send Ether");

        return transferable;
    }

    function getUserEth() public view returns (uint256) {
        return (getTotalEthFromCeth() *
            (balances[msg.sender] / contractBalance));
    }

    function getTotalEthFromCeth() public view returns (uint256) {
        return ceth.balanceOf(address(this)) * ceth.exchangeRateStored();
    }

    function getContractBalance() public view returns (uint256) {
        return contractBalance;
    }

    receive() external payable {}
}
