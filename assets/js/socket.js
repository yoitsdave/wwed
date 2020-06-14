import {Socket} from "phoenix"

export var SocketApp = {
  run: function() {
    
    function handleJoinReply(reply) {
      takeUsers(reply[0])
      window.cur_ethan = reply[1]
    }
    
    function handleStartReply(reply) {
      if ("error" in reply){
        switch (reply['error']) {
          case "no_ethan":
            alert("You haven't selected an ethan!")
            break;
          case "not_enough_players":
            alert("You need three or more players to start a game.")
            break;
          case "already_started":
            alert("Whoops! Someone else already started the round. If it hasn't started for you, try reconnecting.")
            break;
          default:
            alert("Unknown error. I did a fucky wucky :()")
        }
      } else {
        console.log("Round succesfully started")
      }
    }
    
    function startRound() {
      console.log("attempting to start round")
      window.channel.push("ser_start", prompt)
        .receive("ok", handleStartReply)
    }
    
    function handleEthanReply(reply) {
      if ("error" in reply){
        alert("That was an invalid selection! Reverting to " + window.prev_ethan)
        let ethan_select = document.getElementById("ethan_select")
        ethan_select.value = window.prev_ethan
      } else {
        let ethan_select = document.getElementById("ethan_select")
        let ethan = ethan_select.value
        window.prev_ethan = ethan
      }
    }
    
    function failedJoin(reply) {      
      window.socket.disconnect()
      window.socket = new Socket("/socket")
      window.socket.connect()
      
      let room = window.location.href.split("/")[4].split("?pwd=")[0]
      let pwd = window.location.href.split("/")[4].split("?pwd=")[1]
      window.uname = prompt("Join Failed!\n" + reply + "\n If the password is correct, try again:")
      
      window.channel = window.socket.channel("room:"+room, {user: window.uname, pwd: pwd})
      channel.join()
        .receive("ok", resp => { takeUsers(resp) })
        .receive("error", failedJoin)
        
      window.channel.on("cli_setter", takeSetter)
      window.channel.on("cli_prompt", takePrompt)
      window.channel.on("cli_responses", takeResponses)
      window.channel.on("cli_votes", takeVotes)
      window.channel.on("cli_users", takeUsers)
      window.channel.on("cli_paradigm", takeParadigm)
      window.channel.on("cli_ethan", takeEthan)
    }

    function setEthan() {
      window.channel.push("ser_ethan", document.getElementById("ethan_select").value)
        .receive("ok", handleEthanReply)
    }
    
    function handlePromptReply(reply) {
      console.log(reply)
      if ("error" in reply){
        alert("That was an invalid prompt! Keep it emoji-free and shorter than a tweet please. \n Error: " + reply['error'])
      } else {
        let inner = document.getElementById("prompt_inner")
        inner.contentEditable = false
        inner.style.fontStyle = "normal"
      }
    }
    
    function takeSetter(data) {
      window.state = "awaitng_prompt"

      document.getElementById("paradigm").style.visibility = "hidden"; 
      document.getElementById("answer_table").style.visibility = "hidden"; 
      document.getElementById("finals").style.visibility = "hidden"; 

      let inner = document.getElementById("prompt_inner")
      
      console.log("Setter", data['payload'])
      if (data['payload'] == window.uname) {
        let text = document.createTextNode("Type prompt here, and press next when ready")
        inner.removeChild(inner.childNodes[0])
        inner.appendChild(text)
        inner.contentEditable = true
        inner.style.fontStyle = "italic"
        
        let button = document.getElementById("next_text")
        button.removeChild(button.childNodes[0])
        button.appendChild(document.createTextNode("Next"))
        
        document.getElementById("next_button").style.backgroundColor = "orange"
        document.getElementById("next_button").onclick = (
          () => window.channel.push("ser_prompt", document.getElementById("prompt_inner").textContent)
                  .receive("ok", handlePromptReply)
        )
        
      } else {
        let text = document.createTextNode("Waiting for " + data['payload'] + " to set prompt.")
        inner.removeChild(inner.childNodes[0])
        inner.appendChild(text)
        
        let button = document.getElementById("next_text")
        button.removeChild(button.childNodes[0])
        button.appendChild(document.createTextNode("Wait"))
        
        document.getElementById("next_button").style.backgroundColor = "red"
        document.getElementById("next_button").onclick = (
          () => alert("Wait for " + data['payload'] + " to set prompt!")
        )
      }
    }
    
    function handleResponseReply(reply) {
      console.log(reply)
      if ("error" in reply){
        alert("That was an invalid answer! Keep it emoji-free and shorter than 64 characters. \n Error: " + reply['error'])
      } else {
        let answer = document.getElementById("answer_box")
        answer.contentEditable = false
        answer.style.fontStyle = "normal"
      }
    }
    
    function sendResponse() {
      window.channel.push("ser_response", document.getElementById("answer_box").textContent)
              .receive("ok", handleResponseReply)
      
      document.getElementById("next_button").style.backgroundColor = "red"        
      document.getElementById("next_button").onclick = (
        () => alert("Wait for everyone else to submit answers!")
      )
    }
    
    //TODO: If you empty the box and click off of it, it should repopulate
    function takePrompt(data) {
      window.state = "awaitng_responses"
      
      console.log("Prompt: ", data['payload'])
      
      document.getElementById("paradigm").style.visibility = "visible"; 
      
      let prompt = document.getElementById("prompt_inner")
      prompt.removeChild(prompt.childNodes[0])
      prompt.appendChild(document.createTextNode(data['payload']))
      
      let answer = document.getElementById("answer_box")
      answer.style.visibility = "visible";
      answer.removeChild(answer.childNodes[0])
      answer.appendChild(document.createTextNode("Type your answer in here. Press next when ready"))
      answer.contentEditable = true
      answer.style.fontStyle = "italic"
      
      let button = document.getElementById("next_text")
      button.removeChild(button.childNodes[0])
      button.appendChild(document.createTextNode("Next"))

      document.getElementById("next_button").style.backgroundColor = "orange"
      document.getElementById("next_button").onclick = sendResponse
    }
    
    function getVoteReplyFunction(response) {
      function internal (reply) {
        console.log(reply)
        if ("error" in reply){
          alert("That was an invalid vote! If you tried to vote for yourself, you're a nasty one... \n Error: " + reply['error'])
        } else {
          document.getElementById("answer_box_" + response).style.backgroundColor = "blue"
        }
      }
      
      return internal
    }
    
    function getVoteFunction(response) {
      function internal() {
        window.channel.push("ser_vote", response)
                .receive("ok", getVoteReplyFunction(response))
        
        
        document.getElementById("next_button").style.backgroundColor = "red"
        document.getElementById("next_button").onclick = (
          () => alert("Wait for everyone else to vote!")
        )
      }
      
      return internal
    }
    
    function takeResponses(data) {
      window.state = "awaitng_votes"
      
      console.log("Responses: ", data['payload'])

      var answer_table_old = document.getElementById("answer_table")
      var answer_table_new = answer_table_old.cloneNode(false)
      var div, text, response

      for (const idx in data['payload']) {
        response = data['payload'][idx]
        
        div = document.createElement("div")
        text = document.createTextNode(response)
        
        div.appendChild(text)
        div.className = "answer"
        div.id = "answer_box_" + response
        
        div.onclick = getVoteFunction(response)
        
        answer_table_new.appendChild(div)
      }

      answer_table_new.style.visibility = "visible"
      answer_table_old.parentNode.replaceChild(answer_table_new, answer_table_old)
      
      document.getElementById("next_button").style.backgroundColor = "red"
      let button = document.getElementById("next_text")
      button.removeChild(button.childNodes[0])
      button.appendChild(document.createTextNode("Wait"))
      document.getElementById("next_button").onclick = (
        () => alert("Vote by clicking on the answer that matches the question!")
      )
    }
    
    //TODO: disable voting after takeVotes() called
    function takeVotes(data) {
      window.state = "awaiting_start"
      
      console.log("Votes:", data['payload'])
      let votes = data['payload'][0]
      let ethans = data['payload'][1]
      
      let button = document.getElementById("next_text")
      button.removeChild(button.childNodes[0])
      button.appendChild(document.createTextNode("Start!"))

      let max_votes = votes.reduce(
        ((acc, vote) => ((votes.filter((elem) => elem == vote).length) > acc) ?
                       (votes.filter((elem) => elem == vote)).length :
                       acc),
        0
      )
      console.log("Max votes", max_votes)
      let winners = votes.filter(
        (vote) => votes.filter((elem) => elem == vote).length == max_votes
      ).map((winner) => "Winner: " + winner)
      winners = [...new Set(winners)]
      console.log(winners)
      
      let old_votes_node = document.getElementById("final_winner")
      let new_votes_node = old_votes_node.cloneNode(false)
      for (const winner in winners) {
        new_votes_node.appendChild(document.createTextNode(winners[winner]))
        new_votes_node.appendChild(document.createElement("br"))
      }
      old_votes_node.parentNode.replaceChild(new_votes_node, old_votes_node)

      let ethan = document.getElementById("final_ethan")
      ethan.removeChild(ethan.childNodes[0])
      ethan.appendChild(document.createTextNode(
        document.getElementById("ethan_select").value + " said: " + ethans
      ))
      
      document.getElementById("finals").style.visibility = "visible"
      document.getElementById("next_button").style.backgroundColor = "green"

      document.getElementById("next_button").onclick = startRound
    }
        
    function takeUsers(data) {
      console.log("Users:", data['payload'])
      var user_table_old = document.getElementById("user_table")
      var user_table_new = user_table_old.cloneNode(false)
      var option_table_old = document.getElementById("ethan_select")
      var option_table_new = option_table_old.cloneNode(false)
      var div, user_div, score_div, text, option;
      
      if (window.cur_ethan == null) {
        option = document.createElement("option", {value: "nil"})
        text = document.createTextNode("Not Selected")
        option.appendChild(text)
        option_table_new.appendChild(option)
      }

      for (const user in data['payload']) {        
        user_div = document.createElement("div")
        text = document.createTextNode(user)
        user_div.appendChild(text)
        user_div.className = "user"
        
        score_div = document.createElement("div")
        text = document.createTextNode(data["payload"][user])
        score_div.appendChild(text)
        score_div.className = "score"

        div = document.createElement("div")
        div.appendChild(user_div)
        div.appendChild(score_div)
        div.className = "score-row"
        
        option = document.createElement("option", {value: user})
        text = document.createTextNode(user)
        option.appendChild(text)
        
        user_table_new.appendChild(div)
        option_table_new.appendChild(option)
      }
      
      if (window.cur_ethan != null) {
        option_table_new.value = window.cur_ethan
      }
      
      option_table_new.onchange = setEthan

      user_table_old.parentNode.replaceChild(user_table_new, user_table_old)
      option_table_old.parentNode.replaceChild(option_table_new, option_table_old)
      
      console.log("took users, num", Object.keys(data['payload']).length, "state", window.state)
      if (Object.keys(data['payload']).length < 3 && window.state != "awaiting_start") {
        alert("Someone disconnected, bringing the number of players down to 2 and cutting off the round.");
        window.state = "awaiting_start";
        
        document.getElementById("paradigm").style.visibility = "visible"; 
        document.getElementById("answer_table").style.visibility = "visible"; 
        document.getElementById("finals").style.visibility = "visible"; 

        let button = document.getElementById("next_text")
        button.removeChild(button.childNodes[0])
        button.appendChild(document.createTextNode("Start!"))
        
        document.getElementById("next_button").style.backgroundColor = "green"
        document.getElementById("next_button").onclick = startRound
      }
    }
    
    function takeParadigm(data) {
      console.log("Paradigm:", data['payload'])
      let paradigm = document.getElementById("paradigm_inner")
      paradigm.removeChild(paradigm.childNodes[0])
      paradigm.appendChild(document.createTextNode(data['payload']))
    }
    
    function takeEthan(data) {
      console.log("New ethan:", data['payload'])
      document.getElementById("ethan_select").value = data['payload']
      window.cur_ethan = data['payload']
    }
    
    function main() {
      window.socket = new Socket("/socket")
      window.socket.connect()
      
      let room = window.location.href.split("/")[4].split("?pwd=")[0]
      let pwd = window.location.href.split("/")[4].split("?pwd=")[1]
      window.uname = prompt("Username?")
      
      window.channel = socket.channel("room:"+room, {user: window.uname, pwd: pwd})
      window.channel.join()
        .receive("ok", handleJoinReply)
        .receive("error", failedJoin)
            
      window.channel.on("cli_setter", takeSetter) 
      window.channel.on("cli_prompt", takePrompt) 
      window.channel.on("cli_responses", takeResponses) 
      window.channel.on("cli_votes", takeVotes) 
      window.channel.on("cli_users", takeUsers) 
      window.channel.on("cli_paradigm", takeParadigm) 
      window.channel.on("cli_ethan", takeEthan)
      
      document.getElementById("next_button").style.backgroundColor = "green"
      document.getElementById("next_button").onclick = startRound; 
      
      document.getElementById("answer_box").addEventListener("keydown", function(event) {
        if (event.keyCode === 13) {
          event.preventDefault()
          document.getElementById("next_button").click()
        }
      });
      
      document.getElementById("prompt_inner").addEventListener("keydown", function(event) {
        if (event.keyCode === 13) {
          event.preventDefault()
          document.getElementById("next_button").click()
        }
      });
      
      window.state = "awaiting_start";
    }
    
    return [main, startRound, setEthan];
  }
}

