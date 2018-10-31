pragma solidity 0.4.24;

import "../openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "../openzeppelin-solidity/contracts/token/ERC20/PausableToken.sol";
import "../openzeppelin-solidity/contracts/token/ERC20/MintableToken.sol";
import "../openzeppelin-solidity/contracts/token/ERC20/TokenTimelock.sol";

import "../openzeppelin-solidity/contracts/crowdsale/Crowdsale.sol";
import "../openzeppelin-solidity/contracts/crowdsale/emission/MintedCrowdsale.sol";
import "../openzeppelin-solidity/contracts/crowdsale/validation/CappedCrowdsale.sol";
import "../openzeppelin-solidity/contracts/crowdsale/validation/TimedCrowdsale.sol";
import "../openzeppelin-solidity/contracts/crowdsale/validation/WhitelistedCrowdsale.sol";
import "../openzeppelin-solidity/contracts/crowdsale/distribution/RefundableCrowdsale.sol";



contract TestTokenSale is Crowdsale, MintedCrowdsale, CappedCrowdsale, TimedCrowdsale, WhitelistedCrowdsale, RefundableCrowdsale{

	uint256 minPurchase = 2e17; //0.2 ether
	uint256 maxPurchase = 50e18; //50 ether 
	mapping (address => uint256) public contributions;

	enum Stages{
		saleStage1,
		saleStage2
	}

	Stages public stage = Stages.saleStage1;

	// distribution
	uint256 public TokenSalePercentage = 80;
	uint256 public TeamPercentage = 20;

	// funds
	address public teamFund;

	// time lock
	uint256 public releaseTime;
	address public teamTimeLock;

	constructor(
		uint256 _rate, 
		address _wallet, 
		ERC20 _token, 
		uint256 _cap, 
		uint256 _openingTime, 
		uint256 _closingTime,
		uint256 _goal,
		address _teamFund,
		uint256 _releaseTime
	)
	Crowdsale(_rate, _wallet, _token)
	CappedCrowdsale(_cap) 
	TimedCrowdsale(_openingTime, _closingTime)
	RefundableCrowdsale(_goal)
	public {
		require(_goal <= _cap);
		teamFund = _teamFund;
		releaseTime = _releaseTime;

	}

	function getUserContributions(address _beneficiary) public view returns(uint256){
		return contributions[_beneficiary];
	}

	function setCrowdsaleStage(uint256 _stage) public onlyOwner {
		if(uint256(Stages.saleStage1) == _stage) {
			stage = Stages.saleStage1;
		}else if(uint256(Stages.saleStage2) == _stage){
			stage = Stages.saleStage2;
		}

		if(stage == Stages.saleStage1) {
			rate = 500;
		}else if(stage == Stages.saleStage2){
			rate = 250;
		}
	}


	// funds to wallet during stage 1 and to refund wallet during stage 2
	function _forwardFunds() internal {
		if(stage == Stages.saleStage1){
			wallet.transfer(msg.value);
		}else if(stage == Stages.saleStage2){
			super._forwardFunds();
		}
	}


	function _preValidatePurchase(address _beneficiary, uint256 _weiAmount) internal{
		super._preValidatePurchase(_beneficiary, _weiAmount);
		uint256 _existingContributions = contributions[_beneficiary];
		uint256 _newContributions = _existingContributions.add(_weiAmount);
		require(_newContributions >= minPurchase && _newContributions <= maxPurchase);
		contributions[_beneficiary] = _newContributions;
	}

	function finalization() internal {
		if(goalReached()){
			MintableToken _mintableToken = MintableToken(token);

			uint256 _alreadyMinted = _mintableToken.totalSupply();
			uint256 _finalTotalSupply = _alreadyMinted.div(TokenSalePercentage).mul(100);

			teamTimeLock = new TokenTimelock(token, teamFund, releaseTime);

			_mintableToken.mint(address(teamTimeLock), _finalTotalSupply.mul(TeamPercentage).div(100));

			_mintableToken.finishMinting();

			PausableToken _pausableToken = PausableToken(token);
			_pausableToken.unpause();
			_pausableToken.transferOwnership(wallet);
		} 

		super.finalization();

	}
	
}
