pragma solidity ^0.4.23;

import "./builtin.sol";

contract AslVote {
    
    using Builtin for AslVote;
    
    address createurContrat; 
    
    // Définition d'un administrateur:
    mapping (address => bool) admin; 
     
    // Définition d'un membre:
    mapping (address => bool) public membre;
    
    // Il peut être interressant de vérifier le nombre de membres
    uint public nbreMembres = 0;

    
    // Au déploiement du contrat, le créateur du contrat devient automatiquement administrateur et membre
    constructor() public {
        admin[msg.sender] = true;
        membre[msg.sender] = true;
        createurContrat = msg.sender;
        nbreMembres +=1;
    }
    
    // Fonction pour vérifier si l'utilisateur est administrateur
    modifier estAdmin(address _address){
        require(admin[_address] == true);
        _;
    }
    
    // Un administrateur peut rajouter un membre 
    function ajouterMembre(address _membre) public estAdmin(msg.sender){
        membre[_membre] = true;
        nbreMembres +=1;
    }
    
    // Fonction pour vérifier si l'utilisateur est membre
    modifier estMembre(address _membre){
        require(membre[_membre] == true);
        _;
    }
    
    // Un administrateur peut accorder les droits administrateur à un autre membre
    function accorderAdministration(address _membre) public estAdmin(msg.sender) estMembre(_membre){
        admin[_membre] = true;
    }
    
    // Un administrateur peut retirer un membre
    function retirerMembre(address _membre) public estAdmin(msg.sender) estMembre(_membre){
        require(_membre != createurContrat); // Le créateur du contrat ne peut pas être retirer car risque de se retrouver sans admin
        membre[_membre] = false;
        admin[_membre] = false; // Si le membre était admin, il est automatiquement retiré des administrateurs
        nbreMembres -=1;
    }
    
    
    // ------------------------------------------------------------------ //
    // -------------------Proposition de vote---------------------------- //
    // ------------------------------------------------------------------ //
    
    // variable ajustable correspondant au nombre minimum d'accord pour passer une proposition aux votes (parametré pâr défaut à 5)
    uint public nbreAccordNecessaire = 5;
    // Variable ajustable correspondant au nombre minimum de vote pour qu'un resultat soit validé (paramétré par défaut à 8)
    // Un vote ou il n'y a eu qu'une seule personne ayant voté ne peut légitimement pas être pris en compte
    uint public nbreMinimumDeVote = 8;
    
    
    // Seul un administrateur peut changer ces valeurs
    function changerNbreAccord(uint _nouvelleValeur) public estAdmin(msg.sender){
        nbreAccordNecessaire = _nouvelleValeur;
    }
    
    function changerNbreMinimumDeVote(uint _nouvelleValeur) public estAdmin(msg.sender){
        nbreMinimumDeVote = _nouvelleValeur;
    }
    
    struct proposition {
        uint id; // identifiant de la proposition de vote
        string details; // explication concise de la proposition
        uint date; // date de proposition
        uint nbreAccordPourVote; // Il faudra l'accord d'au moins 5 propriétaire pour soumettre une proposition à un vote
        bool voteOuvert; 
        uint nbreVotePour;
        uint nbreVoteContre;
        uint dateLimitePourVoter; // Date jusqu'à laquelle il sera possible de voter
        bool resultat;
    }
    
    // Tableau des propositions
    proposition[] public propositions;
    
    //Fonction permettant de lister les propositions actuelles ou déppassée
    function nbrePropositions() public view returns(uint){
        return propositions.length;
    }
    
    // Pour empécher les membres de voter 2 fois pour une proposition:
    // Seront référencées les adresses des membres ayant donnés leur accord pour que la proposition soit votée
    mapping (uint => address[]) public aDonneAccord;  
    // Référencement des membres ayant voté pour la proposition
    mapping (uint => address[]) public aVote;
    
    function _aDejaDonneSonAccord(uint _id, address _membre)public view returns(bool){
        for(uint i = 0;i < aDonneAccord[_id].length;i++){
            if(aDonneAccord[_id][i] == _membre){
                return(true);
                break;
            } else return false;
        }
    }
    
     function _aDejaVote(uint _id, address _membre)public view returns(bool){
        for(uint i = 0;i < aVote[_id].length;i++){
            if(aVote[_id][i] == _membre){
                return(true);
                break;
            } else return false;
        }
    }
    
    
    function creerProposition (string memory _details) public estMembre(msg.sender){
        propositions.push(proposition(propositions.length,_details,now,0,false,0,0,0,false));
    }

    function donnerAccordPourProposition(uint _id) public estMembre(msg.sender){
        // Le membre ne doit pas avoir déjà donné son accord:
        require(_aDejaDonneSonAccord(_id,msg.sender)==false);
        
        // Nous augmentons de 1 le nombre d'accord pour que la proposition passe en vote
        propositions[_id].nbreAccordPourVote ++;
        // Le membre ne pourra plus donner son accord pour cette proposition
        aDonneAccord[_id].push(msg.sender);
        
        if (propositions[_id].nbreAccordPourVote >= nbreAccordNecessaire){
            // S'il y a un nombre  d'accords suffisant pour passer cette proposition en vote
            // La proposition passe en statut vote ouvert.
            propositions[_id].voteOuvert = true;
            // Elle sera ouverte au vote pendant 30 jours.
            propositions[_id].dateLimitePourVoter = now + 30 days;
        }
    }
    
    function voter(uint _id, bool _vote)public estMembre(msg.sender){
        // Le membre ne doit pas avoir déjà voté pour cette proposition
        require(_aDejaVote(_id,msg.sender)==false);
        // Le membre ne pourra plus voter pour cette proposition
        aVote[_id].push(msg.sender);
        
        if(_vote == true){
            propositions[_id].nbreVotePour++;
        } else {
            propositions[_id].nbreVoteContre++;
        }
        
        // Le vote sera automatiquement fermé si tous les membres ont votés et le resultat sera validé et affiché.
        if(propositions[_id].nbreVotePour + propositions[_id].nbreVoteContre == nbreMembres){
            propositions[_id].voteOuvert = false;
            if(propositions[_id].nbreVotePour > propositions[_id].nbreVoteContre){
                // par défaut le resultat est négatif (false) si le "POUR" l'emporte, il passe en true
                // Une égalité equivaut à un résultat négatif.
                propositions[_id].resultat = true;
            } 
        
        }
    }
    
    // Fonction manuel scellant un vote.
    function fermerVote(uint _id) public estMembre(msg.sender){
        // Necessite que le vote soit ouvert ET que la date limite de vote soit déppassée
        require(propositions[_id].dateLimitePourVoter<now && propositions[_id].voteOuvert==true);
        // Le vote ferme
        propositions[_id].voteOuvert = false;
        // Si plus de votants que nécessaire, le vote est validé
        if(propositions[_id].nbreVotePour + propositions[_id].nbreVoteContre > nbreMinimumDeVote){
            if(propositions[_id].nbreVotePour > propositions[_id].nbreVoteContre){
                // par défaut le resultat est négatif (false) si les pour l'emporte, il passe en true
                // Une égalité equivaut à un vote négatif.
                propositions[_id].resultat = true;
            } 
        }
    }
    
    
    
    
}