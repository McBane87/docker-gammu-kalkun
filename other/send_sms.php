<?php
/*
* @author Azhari Harahap (azhari.harahap@yahoo.com)
* @date Agustus 08, 2010
* @version 0.1 alpha
* @requirement cURL
*/

class Kalkun_API {
        var $base_url = "";
        var $login_url = "login/index";
        var $sms_url = "messages/compose_process";
        var $session_file = "/tmp/cookies.txt"; // must be writable
        var $username = "";
        var $password = "";
        var $phone_number = "";
        var $message = "";
        var $sms_mode = "0"; // 1 = flash, 0 = normal
        //var $send_date = date('Y-m-d H:i:s');
        var $coding = "";
        var $curl_id = "";

        function Kalkun_API($params = array())
        {
                if(count($params) > 0)
                {
                        $this->curl_id = curl_init();
                        $this->login_url = $params['base_url']."".$this->login_url;
                        $this->sms_url = $params['base_url']."".$this->sms_url;
                        $this->initialize($params);
                }
        }

        function initialize($params = array())
        {
                if (count($params) > 0)
                {
                        foreach ($params as $key => $val)
                        {
                                if (isset($this->$key))
                                {
                                        $this->$key = $val;
                                }
                        }
                }

                if (isset($this->message)) $this->message = preg_replace('/\\\\n/', "\n", $this->message);
        }

        function run()
        {
                if($this->login())
                {
                        $ret = $this->send_sms();
                }

                $this->finish();

                if ($ret === FALSE) exit(1);
                exit(0);
        }

        function finish()
        {
                $ch = $this->curl_id;
                curl_close($ch);

                if (file_exists($this->session_file))
                {
                        unlink($this->session_file);
                }
        }

        function login()
        {
                $ch = $this->curl_id;
                curl_setopt($ch, CURLOPT_URL, $this->login_url);
                curl_setopt($ch, CURLOPT_RETURNTRANSFER, TRUE);
                curl_setopt($ch, CURLOPT_FOLLOWLOCATION, TRUE);
                curl_setopt($ch, CURLOPT_POST, TRUE); 
                curl_setopt($ch, CURLOPT_COOKIEJAR, $this->session_file);
                curl_setopt($ch, CURLOPT_COOKIEFILE, $this->session_file);

                $fields = array(
                    'username' => urlencode($this->username),
                    'password' => urlencode($this->password)
                );
                $fields_string = $this->urlify($fields);
                curl_setopt($ch, CURLOPT_POSTFIELDS, $fields_string);
                $output = curl_exec($ch);

                // Check if URL exist
                $http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
                if($http_code == 404 || $http_code === 0) {
                        $this->show_message('URL not found');
                    return FALSE;
                }

                if(strpos($output,"Please enter your username and password") !== false)
                {
                        $this->show_message('Login failed');
                        return FALSE;
                }
                else return TRUE;
        }

        function send_sms()
        {
                $ch = $this->curl_id;
                curl_setopt($ch, CURLOPT_URL, $this->sms_url);
                curl_setopt($ch, CURLOPT_RETURNTRANSFER, TRUE);
                curl_setopt($ch, CURLOPT_FOLLOWLOCATION, TRUE);
                curl_setopt($ch, CURLOPT_POST, TRUE); 
                curl_setopt($ch, CURLOPT_COOKIEJAR, $this->session_file);
                curl_setopt($ch, CURLOPT_COOKIEFILE, $this->session_file);

                $sms = array(
                    'sendoption' => urlencode('sendoption3'),
                    'manualvalue' => urlencode($this->phone_number),
                    'senddateoption' => urlencode('option1'),
                    'sms_mode' => urlencode($this->sms_mode),
                    'sms_loop' => urlencode('1'),
            'validity' => urlencode('-1'),
            'unicode' => urlencode($this->coding),
                    'message' => urlencode($this->message)
                );
                $sms_field = $this->urlify($sms);
                curl_setopt($ch, CURLOPT_POSTFIELDS, $sms_field);
                $output = curl_exec($ch);

                if ($output === FALSE) {
                        $this->show_message('cURL operation failed!');
                        return(FALSE);
                }

                $pure_output = strip_tags(preg_replace('/<\/{0,1}br>/i', "\n", $output));
                $this->show_message($pure_output);

                if (!preg_match('/Your\s*message\s*has\s*been\s*move\s*to\s*Outbox\s*and\s*ready\s*for\s*delivery/i',$pure_output)) {
                        return(FALSE);
                }

                return(TRUE);
        }

        //url-ify the data for the POST
        function urlify($param)
        {
                $param_string = '';
                foreach($param as $key=>$value) 
                { $param_string .= $key.'='.$value.'&'; }
                rtrim($param_string,'&');
                return $param_string;
        }

        function show_message($message)
        {
                echo $message."\n";
        }
}

?>
<?php

$shortopts  = "";
$shortopts .= "u:";  // User
$shortopts .= "p:";  // Password
$shortopts .= "n:";  // Number
$shortopts .= "m:";  // Message
$shortopts .= "H:"; // URL to Kalkun
$shortopts .= "t:"; // Temp Directory
$shortopts .= "h"; // Help

$options = getopt($shortopts);
#var_dump($options);

if (isset($options['h'])) {
        echo "Usage: ". $argv[0] . " [-H <URL>] [-t <CookieDir>] -u <UserName> -p <Password> -n <PhoneNumber> -m <Message>  \n";
        echo "\n\n";
        echo "Options:\n";
        echo "\t -u <UserName>\t Username to use for Login into Kalkun\n";
        echo "\t -p <Password>\t Password to use for Login into Kalkun\n";
        echo "\t -n <Number>\t Phonenumber to send SMS to\n";
        echo "\t -m <Message>\t Message of SMS\n";
        echo "\t -t <CookieDir>\t Writeable directory where temporary cookie will be saved. (Default: /tmp)\n";
        echo "\t -H <URL>\t URL to Kalkun. (Default: http://127.0.0.1/index.php/)\n";
        echo "\n";
}

if (! isset($options['t']) || !$options['t'] || $options['t'] == "") $options['t'] = "/tmp";
if (! isset($options['H']) || !$options['H'] || $options['H'] == "") $options['H'] = "http://127.0.0.1/index.php/";

$required = array('u','p','n','m','H','t');

foreach ($required as $r) {
        if (!isset($options[$r]) || !$options[$r] || trim($options[$r]) == "") {
                echo "Required option \"-$r\" not set!\n";
		exit(1);
        }
}

$TS = time();

$config['base_url'] = $options['H'];
$config['session_file'] = $options['t'] . "/cookies_" . $TS . ".txt";
$config['username'] = $options['u'];
$config['password'] = $options['p'];
$config['phone_number'] = $options['n'];
$config['message'] = $options['m'];

// unicode message
$config['coding'] = 'unicode';

$sms = new Kalkun_API($config);
$sms->run();
?>
